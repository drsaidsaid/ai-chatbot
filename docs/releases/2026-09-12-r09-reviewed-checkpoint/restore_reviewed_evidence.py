import pathlib,json,hashlib,subprocess,sys,tarfile,io
package=pathlib.Path(__file__).resolve().parent
repository=package.parents[2]
report=json.loads((package/'historical-ruby-path-map.json').read_text())
for item in report['mapping']:
 data=(repository/item['packaged']).read_bytes()
 assert hashlib.sha256(data).hexdigest()==item['sha256'],item['packaged']
 assert data==subprocess.check_output(['git','show',report['reviewed_evidence_tree']+':'+item['original']],cwd=repository)
target=pathlib.Path(sys.argv[1]).expanduser().resolve()
assert target!=repository and repository not in target.parents,'Use an external scratch directory'
assert not target.exists() or not any(target.iterdir()),'Scratch directory must be empty'
archive=subprocess.check_output(['git','archive','--format=tar',report['reviewed_evidence_tree']],cwd=repository)
target.mkdir(parents=True,exist_ok=True)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(target,filter='data')
for item in report['mapping']:assert hashlib.sha256((target/item['original']).read_bytes()).hexdigest()==item['sha256']
print(json.dumps({'restored_tree':report['reviewed_evidence_tree'],'scratch_directory':str(target),'historical_payloads':len(report['mapping']),'proofs_executed':False}))
