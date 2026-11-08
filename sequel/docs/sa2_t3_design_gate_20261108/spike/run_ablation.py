import os, subprocess, pathlib, json, time
root=pathlib.Path('/workspace/sa2-t3-audit')
engine=str(root/'tools/Godot_v4.7.2-stable_linux.x86_64')
cases=[('back0_worldhidden',0,11,0,2)]
results=[]
for repeat in range(1,4):
 for name,enemies,npcs,assets,events in cases:
  label=f'{name}_r{repeat}'
  env=dict(os.environ,TOWN='back',DISPLAY=':93',LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=str(root/'user'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME='/tmp/sa2-t3-cache',AUDIT_CASE=label,AUDIT_ENEMIES=str(enemies),AUDIT_NPCS=str(npcs),AUDIT_ASSETS=str(assets),AUDIT_EVENTS=str(events))
  cmd=[engine,'--path',str(root/'runtime'),'--rendering-driver','opengl3','--audio-driver','Dummy','--resolution','1280x720','--disable-vsync','--script','res://audit_noworld.gd']
  t=time.monotonic()
  try:
   log=root/'logs'/f'{label}.log'
   peak=0
   with log.open('w') as out:
    p=subprocess.Popen(cmd,env=env,stdout=out,stderr=subprocess.STDOUT,text=True)
    while p.poll() is None:
     try:
      for line in pathlib.Path(f'/proc/{p.pid}/status').read_text().splitlines():
       if line.startswith('VmRSS:'):peak=max(peak,int(line.split()[1]))
     except FileNotFoundError:pass
     if time.monotonic()-t>75:p.kill();raise subprocess.TimeoutExpired(cmd,75)
     time.sleep(0.1)
   output=log.read_text()
   result=next((json.loads(l[len('AUDIT_RESULT '):]) for l in output.splitlines() if l.startswith('AUDIT_RESULT ')),{})
   result.update(exit_code=p.returncode,process_wall_seconds=time.monotonic()-t)
   result['sampled_peak_rss_kib']=peak
   results.append(result)
   (root/'ablation-measurements.json').write_text(json.dumps(results,indent=2))
   print(label,p.returncode,result.get('fps_wall'),flush=True)
  except subprocess.TimeoutExpired:
   print(label,'TIMEOUT',flush=True)
