import pathlib,subprocess,hashlib,json,sys,os
root=pathlib.Path.cwd();tree,prefix=sys.argv[1:]
items=[];non_release=[];paths=set()
for entry in subprocess.check_output(['git','ls-tree','-rz',tree]).split(b'\0'):
 if not entry:continue
 info,path=entry.split(b'\t',1);mode,kind,oid=info.decode().split();path=path.decode();assert kind=='blob'
 file=root/path;content=os.readlink(file).encode() if mode=='120000' else file.read_bytes()
 actual=hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest();assert actual==oid,(path,oid,actual)
 line=f'{hashlib.sha256(content).hexdigest()}  {path}\n';items.append(line)
 if not path.startswith('docs/releases/'):non_release.append(line);paths.add(path)
changed=subprocess.check_output(['git','diff','--name-only','9a834e756347822d4ae5af15f268a5e8751fc852',tree]).decode().splitlines()
runtime=[p for p in changed if p.startswith(('app/','spec/','db/','config/'))];assert set(runtime)<=paths
(root/f'tmp/r09/{prefix}-all-blobs.sha256').write_text(''.join(items))
(root/f'tmp/r09/{prefix}-non-release.sha256').write_text(''.join(non_release))
(root/f'tmp/r09/{prefix}-runtime-paths.txt').write_text('\n'.join(runtime)+'\n')
report={'source_tree':tree,'total_blobs':len(items),'non_release_blobs':len(non_release),'release_blobs':len(items)-len(non_release),'changed_runtime_test_paths':len(runtime),'all_changed_runtime_paths_included':True,'whole_source_git_blob_mismatches':[]}
(root/f'tmp/r09/{prefix}-inventory.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
