// Trial assets for the size comparison page only. No production character settings are changed.
export const CANDIDATES = {
  c_rana: {name:'ラナ候補',ref:'rana',src:'assets/candidates/rana.jpg'},
  c_rana_tone: {name:'ラナ候補・色調調整',ref:'rana',src:'assets/candidates/rana-tone.webp'},
  c_lily: {name:'リリィ候補',ref:'lily',src:'assets/candidates/lily.jpg'},
  c_guest: {name:'新キャラ（仮）',ref:'garou',src:'assets/candidates/guest.jpg'}
};
export async function candidateImage(src) {
  const raw=await new Promise((resolve,reject)=>{const im=new Image();im.crossOrigin='anonymous';im.onload=()=>resolve(im);im.onerror=()=>reject(Error('候補画像を読み込めません：'+src));im.src=src;});
  const c=document.createElement('canvas');c.width=raw.naturalWidth;c.height=raw.naturalHeight;const g=c.getContext('2d');g.drawImage(raw,0,0);const d=g.getImageData(0,0,c.width,c.height),p=d.data;
  let x0=c.width,y0=c.height,x1=0,y1=0;
  for(let y=0;y<c.height;y++)for(let x=0;x<c.width;x++){const i=(y*c.width+x)*4,r=p[i],green=p[i+1],b=p[i+2],chroma=Math.min(r,b)-green;
    if(r>120&&b>100&&chroma>65){const a=Math.max(0,Math.min(1,(125-chroma)/60));p[i+3]=Math.round(p[i+3]*a);if(a>0){p[i]=Math.min(r,green+45);p[i+2]=Math.min(b,green+45);}}
    if(p[i+3]>60){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}}
  if(x0>x1||y0>y1)throw Error('候補画像に人物がありません');g.putImageData(d,0,0);const out=document.createElement('canvas');out.width=x1-x0+1;out.height=y1-y0+1;out.getContext('2d').drawImage(c,x0,y0,out.width,out.height,0,0,out.width,out.height);
  return new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=reject;im.src=out.toDataURL('image/png');});
}
