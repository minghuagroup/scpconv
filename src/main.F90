
program test

    use netcdf
!    use scp_conv
    use conv_jp, only: conv_jp_init, conv_jp_tend, nplume_sh, nplume_dp
#ifdef SCMDIAG
    use scmdiag, only: subcol_netcdf_init, subcol_netcdf_setdim, subcol_netcdf_end
    use scmdiag, only: subcol_netcdf_addfld
    use scmdiag, only: subcol_netcdf_nextstep
    use scmdiag, only: subcol_netcdf_putclm, subcol_netcdf_putfld
#endif
! Haiyang Yu
    use nnparameter,   only: nnmodel, negqtendadj, profileadj, readnnparameter
!-------------------------------------

    implicit none

    integer,parameter :: r8 = selected_real_kind(12)

!input fields 3D
    real(r8), dimension(:,:,:), allocatable ::           &
        u,            &! u-velocity [m/s]
        v,            &! v-velocity [m/s]
        omega,        &! omega [Ps/s]
        t,            &! temperature [K]
        q,            &! water vapor mixing ratio [kg/kg]
        bfls_t,    &! temperature [K]
        bfls_q,    &! water vapor mixing ratio [kg/kg]
        p,            &! pressure at mid layers [Pa]
        z,            &! height at mid layers [Pa]
!        pi,           &! exner function = temperature/potential temperature
        dp,           &! pressure at full levels [Pa]
        dz,           &! dz between full levels [m]
        rho            ! air density [kg/m^3]

    real(r8), dimension(:,:,:), allocatable ::  camstend, camqtend
    real(r8), dimension(:,:,:), allocatable ::  camstendcond, camqtendcond
    real(r8), dimension(:,:,:), allocatable ::  camstendtranup, camqtendtranup
    real(r8), dimension(:,:,:), allocatable ::  camstendtrandn, camqtendtrandn

    real(r8), dimension(:,:), allocatable :: ht, landfrac, camprecc
    real(r8), dimension(:,:), allocatable :: pblh, tpert, lhflx, nn_prec
    real(r8), dimension(:,:,:), allocatable :: nn_stend, nn_qtend
    real(r8), dimension(:,:), allocatable :: psrf, zsrf
    real(r8), dimension(:), allocatable :: lon, lat, time

!in/out put fields
    real(r8), dimension(:,:,:), allocatable :: massflxbase

!output fields
    real(r8), dimension(:,:,:), allocatable :: stend, qtend, qliqtend, qicetend
    real(r8), dimension(:,:,:), allocatable :: mcon
    real(r8), dimension(:,:,:), allocatable :: h2otend_det
    real(r8), dimension(:,:), allocatable   :: rliq
    real(r8), dimension(:,:), allocatable   :: precc
    real(r8), dimension(:,:), allocatable   :: snow
    real(r8), dimension(:,:,:), allocatable :: qliq, qice
    real(r8), dimension(:,:,:), allocatable :: rainrate, snowrate, precrate
    real(r8), dimension(:,:,:), allocatable :: compstend, compqtend
    real(r8), dimension(:,:,:), allocatable :: dilucape
    real(r8), dimension(:,:), allocatable   :: bfls_dilucape
    real(r8), dimension(:,:), allocatable   :: jctop, jcbot

    real(r8), dimension(:,:), allocatable ::  outmb
    real(r8), dimension(:,:), allocatable ::  outtmp2d
    real(r8), dimension(:,:,:), allocatable ::  outtmp3d, outmse, outmsesat, outmseup
    real(r8), dimension(:,:,:), allocatable ::  outstend, outqtend
    real(r8), dimension(:,:,:), allocatable ::  outstendcond, outqtendcond
    real(r8), dimension(:,:,:), allocatable ::  outstendtranup, outqtendtranup
    real(r8), dimension(:,:,:), allocatable ::  outstendtrandn, outqtendtrandn
    real(r8), dimension(:,:,:), allocatable ::  outstendevap, outqtendevap

!input netcdf id
    integer :: inncid
    integer :: dimIDs(nf90_max_var_dims), ndims
    integer :: nlon, nlat, nlev, ntime, itime, nrun
    integer :: i, j, k
    integer :: lonvarid, latvarid, timevarid
    integer :: uvarid, vvarid, omegavarid, tvarid, qvarid, bfls_tvarid, bfls_qvarid, &
        pvarid, zvarid, &
        pivarid, &
        dzvarid, dpvarid, rhovarid, htvarid, landfracvarid, psrfvarid, zsrfvarid
    integer :: campreccvarid
    integer :: camstendvarid, camqtendvarid
    integer :: camstendcondvarid, camqtendcondvarid
    integer :: camstendtranupvarid, camqtendtranupvarid
    integer :: camstendtrandnvarid, camqtendtrandnvarid


!output netcdf id
    integer :: outncid
    integer :: outlondimid, outlatdimid, outlevdimid, outtimedimid

    integer :: outlonvarid, outlatvarid, outtimevarid
    integer :: outpreccvarid, outcampreccvarid
    integer :: outstendvarid, outqtendvarid, outpvarid
    integer :: outcamstendvarid, outcamqtendvarid

!local
    real(r8) :: dtime, qmin
    logical  :: flag
    integer  :: nplume 

!field input
!    call netcdf_check( nf90_open("inputgcm.nc", NF90_NOWRITE, inncid) )
    call netcdf_check( nf90_open("inputscm_core_paper.nc", NF90_NOWRITE, inncid) )
!    call netcdf_check( nf90_open("inputscm_core_select_new.nc", NF90_NOWRITE, inncid) )
!   call netcdf_check( nf90_open("inputscm_core_all.nc", NF90_NOWRITE, inncid) )
!   call netcdf_check( nf90_open("inputscm.nc", NF90_NOWRITE, inncid) )
!    call netcdf_check( nf90_open("inputscm_clean.nc", NF90_NOWRITE, inncid) )

!get dimension information
    call netcdf_check( nf90_inq_varid(inncid, "u", uvarid) )
    call netcdf_check( nf90_inquire_variable(inncid, uvarid, dimids=dimIDs) )
    call netcdf_check( nf90_inquire_dimension(inncid, dimIDs(1), len = nlon) )
    call netcdf_check( nf90_inquire_dimension(inncid, dimIDs(2), len = nlat) )
    call netcdf_check( nf90_inquire_dimension(inncid, dimIDs(3), len = nlev) )
    call netcdf_check( nf90_inquire_dimension(inncid, dimIDs(4), len = ntime) )

!allocated variables
    call init(nlon, nlat, nlev, ntime)

!get input for lon and lat
    call netcdf_check( nf90_inq_varid(inncid, "lon", lonvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "lat", latvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "time", timevarid) )
    call netcdf_check( nf90_get_var(inncid, lonvarid, lon, start=(/1/), count=(/nlon/) ) )
    call netcdf_check( nf90_get_var(inncid, latvarid, lat, start=(/1/), count=(/nlat/) ) )
    call netcdf_check( nf90_get_var(inncid, timevarid, time, start=(/1/), count=(/ntime/) ) )


!output definition
!    call netcdf_check( nf90_create("diaggcm.nc", NF90_CLOBBER, outncid) )
   call netcdf_check( nf90_create("diagscm.nc", NF90_CLOBBER, outncid) )

    call netcdf_check( nf90_def_dim( outncid, "lon", nlon, outlondimid) )
    call netcdf_check( nf90_def_dim( outncid, "lat", nlat, outlatdimid) )
    call netcdf_check( nf90_def_dim( outncid, "lev", nlev, outlevdimid) )
    call netcdf_check( nf90_def_dim( outncid, "time", NF90_UNLIMITED, outtimedimid) )
!output 2D variables
    call netcdf_check( nf90_def_var(outncid, "lon", NF90_REAL, &
        (/outlondimid/), outlonvarid) )
    call netcdf_check( nf90_def_var(outncid, "lat", NF90_REAL, &
        (/outlatdimid/), outlatvarid) )
    call netcdf_check( nf90_def_var(outncid, "time", NF90_REAL, &
        (/outtimedimid/), outtimevarid) )

    call netcdf_check( nf90_def_var(outncid, "precc", NF90_REAL, &
        (/outlondimid, outlatdimid, outtimedimid/), outpreccvarid) )
    call netcdf_check( nf90_def_var(outncid, "camprecc", NF90_REAL, &
        (/outlondimid, outlatdimid, outtimedimid/), outcampreccvarid) )
!output 3D variables
    call netcdf_check( nf90_def_var(outncid, "p", NF90_REAL, &
        (/outlondimid, outlatdimid, outlevdimid, outtimedimid/), outpvarid) )
    call netcdf_check( nf90_def_var(outncid, "stend", NF90_REAL, &
        (/outlondimid, outlatdimid, outlevdimid, outtimedimid/), outstendvarid) )
    call netcdf_check( nf90_def_var(outncid, "qtend", NF90_REAL, &
        (/outlondimid, outlatdimid, outlevdimid, outtimedimid/), outqtendvarid) )
    call netcdf_check( nf90_def_var(outncid, "camstend", NF90_REAL, &
        (/outlondimid, outlatdimid, outlevdimid, outtimedimid/), outcamstendvarid) )
    call netcdf_check( nf90_def_var(outncid, "camqtend", NF90_REAL, &
        (/outlondimid, outlatdimid, outlevdimid, outtimedimid/), outcamqtendvarid) )

    call netcdf_check( nf90_enddef(outncid) )


!get input variables id
    call netcdf_check( nf90_inq_varid(inncid, "v", vvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "omega", omegavarid) )
    call netcdf_check( nf90_inq_varid(inncid, "p", pvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "z", zvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "t", tvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "q", qvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "bfls_t", bfls_tvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "bfls_q", bfls_qvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "dp", dpvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "dz", dzvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "rho", rhovarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camstend", camstendvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camqtend", camqtendvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camstendcond", camstendcondvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camqtendcond", camqtendcondvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camstendtranup", camstendtranupvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camqtendtranup", camqtendtranupvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camstendtrandn", camstendtrandnvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camqtendtrandn", camqtendtrandnvarid) )

    call netcdf_check( nf90_inq_varid(inncid, "ht", htvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "landfrac", landfracvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "camprecc", campreccvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "psrf", psrfvarid) )
    call netcdf_check( nf90_inq_varid(inncid, "zsrf", zsrfvarid) )


    write(*,*) "nlon:", nlon, "nlat:", nlat, "nlev:", nlev, "ntime:", ntime

    call conv_jp_init(nlev)

    nplume = nplume_sh + nplume_dp
#ifdef SCMDIAG
!init subcol_netcdf
    call subcol_netcdf_setdim( nplume, nlev)
    call subcol_netcdf_init( "scmdiag-output.nc" )
    call subcol_netcdf_addfld( "mse", "J/kg", "mlev")
    call subcol_netcdf_addfld( "msesat", "J/kg", "mlev")
    call subcol_netcdf_addfld( "z", "m", "mlev")
    call subcol_netcdf_addfld( "p", "Pa", "mlev")
    call subcol_netcdf_addfld( "rho", "kg/kg", "mlev")

    call subcol_netcdf_addfld( "mseint", "J/kg", "mlevp")
    call subcol_netcdf_addfld( "msesatint", "J/kg", "mlevp")

    call subcol_netcdf_addfld( "mse_closure", "J/kg", "mlev")

    call subcol_netcdf_addfld( "t", "K", "mlev")
    call subcol_netcdf_addfld( "q", "kg/kg", "mlev")
    call subcol_netcdf_addfld( "qsat", "kg/kg", "mlev")

    call subcol_netcdf_addfld( "dse", "J/kg", "mlev")

    call subcol_netcdf_addfld( "ent_rate", "1", "mlev")
    call subcol_netcdf_addfld( "det_rate", "1", "mlev")
    call subcol_netcdf_addfld( "ent_rate_sh", "1", "mlev")
    call subcol_netcdf_addfld( "det_rate_sh", "1", "mlev")
    call subcol_netcdf_addfld( "bs_xc", "1", "mlev")
    call subcol_netcdf_addfld( "buoy_closure", "m/s2", "mlev")

    call subcol_netcdf_addfld( "diffdse_up", "J/kg", "mlevp")
    call subcol_netcdf_addfld( "diffq_up", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "diffdse_dn", "J/kg", "mlevp")
    call subcol_netcdf_addfld( "diffq_dn", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "qcheck", "kg/kg", "slev")

    call subcol_netcdf_addfld( "w_up_mid", "m/s", "mlev")
    call subcol_netcdf_addfld( "buoy_mid", "m/s2", "mlev")
    call subcol_netcdf_addfld( "mse_up_mid", "m/s", "mlev")
    call subcol_netcdf_addfld( "t_up_mid", "kg/kg", "mlev")
    call subcol_netcdf_addfld( "q_up_mid", "kg/kg", "mlev")
    call subcol_netcdf_addfld( "normassflx_up_mid", "1", "mlev")

    call subcol_netcdf_addfld( "zint", "m/s", "mlevp")
    call subcol_netcdf_addfld( "pint", "m/s", "mlevp")
    call subcol_netcdf_addfld( "qint", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "qsatint", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "tint", "K", "mlevp")

    call subcol_netcdf_addfld( "w_up_init", "m/s", "slev")
    call subcol_netcdf_addfld( "w_up", "m/s", "mlevp")
    call subcol_netcdf_addfld( "buoy", "m/s2", "mlevp")
    call subcol_netcdf_addfld( "radius_up", "m/s2", "mlevp")
    call subcol_netcdf_addfld( "dse_up", "J/kg", "mlevp")
    call subcol_netcdf_addfld( "mse_up", "m/s", "mlevp")
    call subcol_netcdf_addfld( "t_up", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "q_up", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "qliq_up", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "qice_up", "kg/kg", "mlevp")
    call subcol_netcdf_addfld( "normassflx_up", "1", "mlevp")
    call subcol_netcdf_addfld( "mse_up_plume", "J/kg", "mlevp")

    call subcol_netcdf_addfld( "mse_dn", "m/s", "mlevp")
    call subcol_netcdf_addfld( "normassflx_dn", "1", "mlevp")

    call subcol_netcdf_addfld( "camstend", "K/s", "mlev")
    call subcol_netcdf_addfld( "camqtend", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "camstendcond", "K/s", "mlev")
    call subcol_netcdf_addfld( "camqtendcond", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "camstendtranup", "K/s", "mlev")
    call subcol_netcdf_addfld( "camqtendtranup", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "camstendtrandn", "K/s", "mlev")
    call subcol_netcdf_addfld( "camqtendtrandn", "kg/kg/s", "mlev")

    call subcol_netcdf_addfld( "stend",     "K/s",     "mlev")
    call subcol_netcdf_addfld( "qtend",     "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "stendcond", "K/s",     "mlev")
    call subcol_netcdf_addfld( "qtendcond", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "stendtranup", "K/s",     "mlev")
    call subcol_netcdf_addfld( "qtendtranup", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "stendtrandn", "K/s",     "mlev")
    call subcol_netcdf_addfld( "qtendtrandn", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "qliqtenddet", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "stendcomp", "K/s",     "mlev")
    call subcol_netcdf_addfld( "qtendcomp", "kg/kg/s", "mlev")

    call subcol_netcdf_addfld( "stendsum",    "K/s",  "mlev")
    call subcol_netcdf_addfld( "qtendsum",    "K/s",  "mlev")
    call subcol_netcdf_addfld( "qliqtendsum",    "K/s",  "mlev")
    call subcol_netcdf_addfld( "qicetendsum",    "K/s",  "mlev")
    call subcol_netcdf_addfld( "precsum",     "1",  "slev")
    call subcol_netcdf_addfld( "massflxsum",  "1",  "mlevp")
    call subcol_netcdf_addfld( "massflx",  "1",  "mlevp")

    call subcol_netcdf_addfld( "tmp1stend", "K/s", "mlev")
    call subcol_netcdf_addfld( "tmp1qtend", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "tmp2stend", "K/s", "mlev")
    call subcol_netcdf_addfld( "tmp2qtend", "kg/kg/s", "mlev")

    call subcol_netcdf_addfld( "stendevap", "K/s", "mlev")
    call subcol_netcdf_addfld( "qtendevap", "kg/kg/s", "mlev")

    call subcol_netcdf_addfld( "mseqi",    "J/kg/m", "mlev")
    call subcol_netcdf_addfld( "condrate", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "evaprate", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "rainrate", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "snowrate", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "precrate", "kg/kg/s", "mlev")
    call subcol_netcdf_addfld( "accuprec", "kg/m2/s", "mlev")

    call subcol_netcdf_addfld( "prec", "1", "slev")
    call subcol_netcdf_addfld( "dilucape", "1", "slev")
    call subcol_netcdf_addfld( "pmassflxbase", "1", "slev")
    call subcol_netcdf_addfld( "massflxbase", "1", "slev")
    call subcol_netcdf_addfld( "massflxbase_cape", "1", "slev")
    call subcol_netcdf_addfld( "massflxbase_w", "1", "slev")
    call subcol_netcdf_addfld( "massflxbase_mconv", "1", "slev")

    call subcol_netcdf_addfld( "capefc", "1", "slev")

    call subcol_netcdf_addfld( "nconvlev", "1", "slev")
    call subcol_netcdf_addfld( "kuplaunch", "1", "slev")
    call subcol_netcdf_addfld( "kupbase", "1", "slev")
    call subcol_netcdf_addfld( "kuplcl" , "1", "slev")

    call subcol_netcdf_addfld( "trigdp" , "1", "slev")
#endif

  ! Haiyang Yu
    call readnnparameter('atm_in')
    
    
    !if ( ntime == 1 ) then
        !dtime = 0.25*24*3600
    !else
        !dtime = (time(2)-time(1))*24*3600
    !end if
    dtime = 1200._r8
    qmin = 1.E-12_r8

    massflxbase = 0._r8
    lat = lat/180._r8*3.141592653_r8

!   nrun = 35
    nrun = ntime
!simulation begins
    do itime=1,nrun

        write(*,"(a12,i5)") "time step:", itime

!input 3D fields
        call netcdf_check( nf90_get_var(inncid, uvarid, u, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, vvarid, v, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, omegavarid, omega, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, zvarid, z, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, pvarid, p, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, tvarid, t, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, qvarid, q, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, bfls_tvarid, bfls_t, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, bfls_qvarid, bfls_q, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
      !call netcdf_check( nf90_get_var(inncid, pivarid, pi, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, dpvarid, dp, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, dzvarid, dz, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
      !call netcdf_check( nf90_get_var(inncid, rhovarid, rho, start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )

        call netcdf_check( nf90_get_var(inncid, camstendvarid, camstend,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camqtendvarid, camqtend,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )

        call netcdf_check( nf90_get_var(inncid, camstendcondvarid, camstendcond,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camqtendcondvarid, camqtendcond,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camstendtranupvarid, camstendtranup,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camqtendtranupvarid, camqtendtranup,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camstendtrandnvarid, camstendtrandn,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_get_var(inncid, camqtendtrandnvarid, camqtendtrandn,&
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )

!input 2d variables
        call netcdf_check( nf90_get_var(inncid, htvarid, ht(:,:),             start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
        call netcdf_check( nf90_get_var(inncid, landfracvarid, landfrac(:,:), start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
        call netcdf_check( nf90_get_var(inncid, campreccvarid, camprecc(:,:), start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
        call netcdf_check( nf90_get_var(inncid, psrfvarid, psrf(:,:), start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
        call netcdf_check( nf90_get_var(inncid, zsrfvarid, zsrf(:,:), start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )


!run the scheme here
        precc = 0._r8
        stend = 0._r8
        qtend = 0._r8
        stend = 0._r8

        pblh = 0._r8
        tpert = 0.0_r8
        nn_prec = 0.0_r8
        nn_stend = 0.0_r8
        nn_qtend = 0.0_r8
        lhflx = 0._r8
       !psrf = 0._r8
       !zsrf = 0._r8

#ifdef SCMDIAG
        call subcol_netcdf_nextstep
#endif
    
        ! Haiyang test
        landfrac = 0.0

        do j = 1, nlat
            ! ---------------------------------------------------------------
            ! Haiyang Yu: nnmodel
            do i = 1,nlon
                if ( landfrac(i,j)<0.5 ) then
                    call nnmodel(nlev, landfrac(i,j), p(i,j,:), u(i,j,:), v(i,j,:), t(i,j,:), q(i,j,:), z(i,j,:), omega(i,j,:), &
                           nn_stend(i,j,:), nn_qtend(i,j,:), qliqtend(i,j,:), nn_prec(i,j), rainrate(i,j,:), mcon(i,j,:) )
                end if
            end do
            ! ---------------------------------------------------------------
            call conv_jp_tend( nlon &
                ,2, dtime, qmin &
                ,lat(j), landfrac(:,j), lhflx(:,j) &
                ,psrf(:,j), p(:,j,:), dp(:,j,:) &
                ,ht(:,j), z(:,j,:), dz(:,j,:) &
                ,t(:,j,:), q(:,j,:), bfls_t(:,j,:), bfls_q(:,j,:) &
                ,omega(:,j,:), pblh(:,j), tpert(:,j)&
                ,nn_prec(:,j), nn_stend(:,j,:), nn_qtend(:,j,:) &
!
                ,massflxbase(:,j,:) &
                ,jctop(:,j), jcbot(:,j) &
                ,stend(:,j,:), qtend(:,j,:) &
                ,qliqtend(:,j,:), precc(:,j), qliq(:,j,:), rainrate(:,j,:) &
                ,mcon(:,j,:) &
!
!              ,massflxbase(:,j) &
!              ,stend(:,j,:), qtend(:,j,:), qliqtend, qicetend &
!              ,precc(:,j), qliq(:,j,:), qice(:,j,:) & 
!              ,rainrate(:,j,:), snowrate(:,j,:), precrate(:,j,:) &
!
                ,compstend(:,j,:), compqtend(:,j,:) &
                ,dilucape(:,j,:), bfls_dilucape(:,j) &
                ,outtmp2d, outtmp3d &
                ,outmb, outmse, outmsesat, outmseup &
                ,outstend, outqtend &
                ,outstendcond,   outqtendcond &
                ,outstendtranup, outqtendtranup &
                ,outstendtrandn, outqtendtrandn &
                ,outstendevap,   outqtendevap &
                )
            ! ---------------------------------------------------------------
#ifdef SCMDIAG
    do k = 1,nlev
        write(*, '(a10, 3F10.4)') "stend:", p(1,j,k)/100.0, nn_stend(1,j,k), stend(1,j,k)
    end do
#endif
            ! Haiyang Yu: nnmodel
            do i = 1,nlon
                if ( landfrac(i,j)<0.5 ) then
                    call profileadj(nlev, nn_prec(i,j), precc(i,j), stend(i,j,:), qtend(i,j,:), &
                        rainrate(i,j,:), qliqtend(i,j,:), mcon(i,j,:) )
                    call negqtendadj(nlev, q(i,j,:), qtend(i,j,:), stend(i,j,:), &
                        rainrate(i,j,:), qliqtend(i,j,:), mcon(i,j,:), dtime, 1.0e-12_r8)
                end if
            end do

#ifdef SCMDIAG
    write(*, *) "final prec: ", precc(:,j)*86400*1000.0
#endif
            ! ---------------------------------------------------------------
        end do

        do j=1, nlat
            do i=1, nlon
                flag = .false.
                do k=1,nlev
                    if( isnan(stend(i,j,k)) .or. &
                        isnan(qtend(i,j,k)) .or. &
                        isnan(qliq(i,j,k)) .or. &
                        isnan(rainrate(i,j,k)) ) then
                        flag = .true.
                        exit
                    end if
                end do
                if( flag ) then
                    write(*,*) "NAN error in SCP"
                    write(*,*) "s"
                    write(*,*) stend(i,j,:)
                    write(*,*) "q"
                    write(*,*) qtend(i,j,:)
                    write(*,*) "ql"
                    write(*,*) qliq(i,j,:)
                    write(*,*) "qi"
                    write(*,*) qice(i,j,:)
                    write(*,*) "rprd"
                    write(*,*) rainrate(i,j,:)
                end if
            end do
        end do

!scmdiag output
#ifdef SCMDIAG
        call subcol_netcdf_putclm( "camstend", nlev, camstend(1,1,:), 1 )
        call subcol_netcdf_putclm( "camqtend", nlev, camqtend(1,1,:), 1 )
        call subcol_netcdf_putclm( "camstendcond", nlev, camstendcond(1,1,:), 1 )
        call subcol_netcdf_putclm( "camqtendcond", nlev, camqtendcond(1,1,:), 1 )
        call subcol_netcdf_putclm( "camstendtranup", nlev, camstendtranup(1,1,:), 1 )
        call subcol_netcdf_putclm( "camqtendtranup", nlev, camqtendtranup(1,1,:), 1 )
        call subcol_netcdf_putclm( "camstendtrandn", nlev, camstendtrandn(1,1,:), 1 )
        call subcol_netcdf_putclm( "camqtendtrandn", nlev, camqtendtrandn(1,1,:), 1 )
    
    
#endif




!output SCP 2D fields
        call netcdf_check( nf90_put_var(outncid, outpreccvarid, precc, &
            start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
        call netcdf_check( nf90_put_var(outncid, outcampreccvarid, camprecc, &
            start=(/1,1,itime/), count=(/nlon,nlat,1/) ) )
!output SCP 3D fields
        call netcdf_check( nf90_put_var(outncid, outpvarid, p, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_put_var(outncid, outstendvarid, stend, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_put_var(outncid, outqtendvarid, qtend, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )

        call netcdf_check( nf90_put_var(outncid, outcamstendvarid, camstend, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )
        call netcdf_check( nf90_put_var(outncid, outcamqtendvarid, camqtend, &
            start=(/1,1,1,itime/), count=(/nlon,nlat,nlev,1/) ) )

    end do


#ifdef SCMDIAG
!end subcol_netcdf
    call subcol_netcdf_end
#endif


!output lat and lon dimension information
    call netcdf_check( nf90_put_var(outncid, outlonvarid, lon, &
        start=(/1/), count=(/nlon/) ) )
    call netcdf_check( nf90_put_var(outncid, outlatvarid, lat, &
        start=(/1/), count=(/nlat/) ) )
    call netcdf_check( nf90_put_var(outncid, outtimevarid, time, &
        start=(/1/), count=(/nrun/) ) )


!close the input and output NETCDF
    call netcdf_check( nf90_close(inncid) )
    call netcdf_check( nf90_close(outncid) )


    contains

    subroutine netcdf_check( status )
        integer, intent ( in) :: status

        if(status /= nf90_noerr) then
            print *, trim(nf90_strerror(status))
            stop "Stopped"
        end if
    end subroutine netcdf_check


    subroutine init(innlon, innlat, innlev, inntime)
        integer, intent(in) :: innlon, innlat, innlev, inntime
!for dimension info
        allocate( lon(innlon) )
        allocate( lat(innlat) )
        allocate( time(inntime) )
!for input
        allocate( p(innlon, innlat, innlev) )
        allocate( dp(innlon, innlat, innlev) )
        allocate( z(innlon, innlat, innlev) )
        allocate( dz(innlon, innlat, innlev) )
        allocate( u(innlon, innlat, innlev) )
        allocate( v(innlon, innlat, innlev) )
        allocate( omega(innlon, innlat, innlev) )
        allocate( t(innlon, innlat, innlev) )
        allocate( q(innlon, innlat, innlev) )

        allocate( bfls_t(innlon, innlat, innlev) )
        allocate( bfls_q(innlon, innlat, innlev) )

        allocate( ht(innlon, innlat) )
        allocate( landfrac(innlon, innlat) )
        allocate( pblh(innlon, innlat) )
        allocate( tpert(innlon, innlat) )
        allocate( nn_prec(innlon, innlat) )
        allocate( nn_stend(innlon, innlat, innlev) )
        allocate( nn_qtend(innlon, innlat, innlev) )
        allocate( lhflx(innlon, innlat) )
        allocate( psrf(innlon, innlat) )
        allocate( zsrf(innlon, innlat) )

        allocate( camprecc(innlon, innlat) )
        allocate( camstend(innlon, innlat, innlev) )
        allocate( camqtend(innlon, innlat, innlev) )
        allocate( camstendcond(innlon, innlat, innlev) )
        allocate( camqtendcond(innlon, innlat, innlev) )
        allocate( camstendtranup(innlon, innlat, innlev) )
        allocate( camqtendtranup(innlon, innlat, innlev) )
        allocate( camstendtrandn(innlon, innlat, innlev) )
        allocate( camqtendtrandn(innlon, innlat, innlev) )

        allocate( outmb(innlon, innlat) )
        allocate( outtmp2d(innlon, innlat) )
        allocate( outtmp3d(innlon, innlat, innlev) )
        allocate( outmse(innlon, innlat, innlev) )
        allocate( outmsesat(innlon, innlat, innlev) )
        allocate( outmseup(innlon, innlat, innlev) )

        allocate( outstend(innlon, innlat, innlev) )
        allocate( outqtend(innlon, innlat, innlev) )
        allocate( outstendcond(innlon, innlat, innlev) )
        allocate( outqtendcond(innlon, innlat, innlev) )
        allocate( outstendtranup(innlon, innlat, innlev) )
        allocate( outqtendtranup(innlon, innlat, innlev) )
        allocate( outstendtrandn(innlon, innlat, innlev) )
        allocate( outqtendtrandn(innlon, innlat, innlev) )
        allocate( outstendevap(innlon, innlat, innlev) )
        allocate( outqtendevap(innlon, innlat, innlev) )

!for in/output
        allocate( massflxbase(innlon, innlat, innlev) )

!for output
        allocate( jctop(innlon, innlat) )
        allocate( jcbot(innlon, innlat) )

        allocate( stend(innlon, innlat, innlev) )
        allocate( qtend(innlon, innlat, innlev) )
        allocate( qliqtend(innlon, innlat, innlev) )
        allocate( qicetend(innlon, innlat, innlev) )

        allocate( mcon(innlon, innlat, innlev+1) )
        allocate( h2otend_det(innlon, innlat, innlev) )
        allocate( rliq(innlon, innlat) )

        allocate( precc(innlon, innlat) )
        allocate( snow(innlon, innlat) )
        allocate( qliq(innlon, innlat, innlev) )
        allocate( qice(innlon, innlat, innlev) )
        allocate( rainrate(innlon, innlat, innlev) )
        allocate( snowrate(innlon, innlat, innlev) )
        allocate( precrate(innlon, innlat, innlev) )
        allocate( compstend(innlon, innlat, innlev) )
        allocate( compqtend(innlon, innlat, innlev) )

        allocate( dilucape(innlon, innlat, innlev) )
        allocate( bfls_dilucape(innlon, innlat) )

!for local
!       allocate( stend(innlon, innlat, innlev) )

    end subroutine init


    end program test

