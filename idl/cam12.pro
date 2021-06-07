
 print,''
 print,' run scm1.pro first!'
 print,'input file:     ',filein1
 print, 'iapcase=',caseiap


 ncdf_vars,filein2,vars2
 x = get_fld(filein2,'time')
 y = get_fld(filein2,'lev')
; xrange=[min(x),max(x)]

 y2 = get_fld(filein2,'ilev')
; y2 = get_fld(filein2,'LEV')
 ny2 = n_elements(y2)

vars=['CLOUD','TDIFF','QDIFF','T','Q','OMEGA','PBLH','PRECT']
vars=['CLOUD','TDIFF','QDIFF','PBLH','PRECT']
vars=['PRECT']
vars=['CLOUD','RELHUM','QDIFF']
;vars=['RELHUM']
vars=['CAPE','PRECT']
vars=['CLOUD','cufrc_Cu','CONCLD','ICECLDF','LCLOUD']
vars=['TDIFF','QDIFF','CAPE','PRECT','CLOUD']
vars=['TDIFF','QDIFF','PRECT']
vars=['OMEGA','CMFMC']
vars=['OMEGA'] 
vars=['CLOUD','RELHUM']
vars=['CLDLIQ','CLDICE','RELHUM','CLOUD']
vars=['CLOUD']
vars=['CLOUD','RELHUM','TDIFF','QDIFF','PBLH','PRECT']
vars=['TDIFF','QDIFF','RELHUM']
vars=['TDIFF','QDIFF']
vars=['CLOUD']
vars=['QDIFF']

 for iv = 37,n_elements(vars2)-1 do begin
;================

 y = get_fld(filein2,'lev')
  var = vars2[iv]

if(belongsto(var,vars))then begin
title=caseiap+'_'+var
window,/free,xsize=600,ysize=460,title = title

 print,var
  title   = caseiap+'_'+var
  aa = get_fld(filein2,var)
  aa = reform(aa)
  siz = size(aa)
  siz0 = siz[0]

  ;levc = get_lev(aa,var,scale=scale)
  get_lev,aa,var,levc,scale
  ;if(var eq 'RELHUM')then levc = cal_lev([0,100.],20)
  ;if(var eq 'CLOUD')then levc = cal_lev([0,1.],20)
  if(belongsto(var, ['cufrc_Cu', 'LCLOUD', 'CONCLD','ICEFRAC', $
         'ICECLDF']))then $
  get_lev,aa,'CLOUD',levc,scale

  if(var eq 'PRECT')then levc=3.*levc

  aa   = scale*aa
  data_range = [min(levc),max(levc)]
;------------------------
if(siz0 eq 1 )then begin
  gif_file= gif_folder+'/1_'+title+'.gif'

  for ii=0,1 do begin
   plot,x,aa,xtitle='time',ytitle=var,xrange=xrange,$
     title = title+' min:'+strtrim(min(aa),2)+'  max:'+strtrim(max(aa),2) + $
       ' scaled by '+strtrim(scale,2),thick=2,$
    max_v = data_range[1],min_v=data_Range[0]
  endfor

  if(var eq 'PRECT')then begin
   precc = get_fld(filein2,'PRECC')*scale
   preccdzm = get_fld(filein2,'PRECCDZM')*scale
   precl = get_fld(filein2,'PRECL')*scale
   preccsh = precc - preccdzm
  ; oplot,x, precc, color=colors.red
   oplot,x, preccdzm, color=colors.red
   oplot,x, preccsh, color=colors.green
   oplot,x, precl, color=colors.blue
   oplot,x, aa, color=colors.black, thick=2
  endif
endif   
if(siz0 eq  2)then begin

;; if(var eq 'TDIFF')then stop
  gif_file= gif_folder+'/2_'+title+'.gif'

  lev1 = levc
  bb = aa
  lev2 = levc
  lev2 = [10000.,20000]

  y= get_fld(filein2,'lev')
  if(n_elements(aa[*,0]) eq ny2) then y=y2 ; get_fld(filein2,'LEV')  
 
  jj=where(aa eq 0,cnt) & if(cnt gt 0)then aa[jj] = lev1[0]-1
    if(min(aa) ne max(aa))then $
   plot_4dhtml,aa,bb,x,y,lev1,lev2,xrange=xrange,$
      yrange=yrange,xtitle='time',tran=1,$
      title= title+' min:'+strtrim(min(aa),2)+'  max:'+strtrim(max(aa),2)+ $
      ' scaled by '+strtrim(scale,2)
endif

 if(igif)then begin
  mygif,gif_file
  print,var, ' ', gif_file
 endif 
 if(iix)then read,ix

endif ;belongs to

 endfor ; variable
;==================

dir ='/Users/minghuazhang/unix/workgcm/'
if(igif)then begin
 htmlfile = 'html/'+caseiap+'.html'
 gifgroups = file_search(dir+gif_folder+'/*.gif')
 web_view,gifgroups,htmlfile,title=title,ncolumns=2
 print,'webfile:',htmlfile
endif

end