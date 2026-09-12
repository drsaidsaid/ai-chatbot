import os,pathlib,subprocess,json,hashlib,datetime
root=pathlib.Path.cwd();tmp=root/'tmp/r09'
report=json.loads((tmp/'r09-verified-rubocop-results.json').read_text())
paths=sorted(f['path'] for f in report['files'] if any(o['cop_name'].startswith('Layout/') for o in f['offenses']))
cops=sorted({o['cop_name'] for f in report['files'] for o in f['offenses'] if o['cop_name'].startswith('Layout/')})
e=os.environ.copy();e['GIT_INDEX_FILE']=str(tmp/'layout-only.index')
def git(*args):return subprocess.check_output(['git',*args],env=e).decode().strip()
def snapshot():
 git('read-tree','HEAD');git('add','-A','--','.');return git('write-tree')
before=snapshot();git('update-ref','refs/r09/layout-only-before-source-20260912',before,'0'*40)
backup=tmp/'layout-only-before';backup.mkdir(exist_ok=True)
for path in paths:
 target=backup/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((root/path).read_bytes())
parser=tmp/'normalized_ruby_ast.rb'
parser.write_text('''require 'ripper'
require 'json'
require 'digest'
def normalize(value)
  return value unless value.is_a?(Array)
  if value.first.is_a?(Symbol) && value.first.to_s.start_with?('@')
    value[0, 2].map { |item| normalize(item) }
  else
    value.map { |item| normalize(item) }
  end
end
result = ARGV.to_h do |path|
  parsed = Ripper.sexp(File.read(path))
  abort "Unable to parse #{path}" unless parsed
  [path, Digest::SHA256.hexdigest(JSON.generate(normalize(parsed)))]
end
puts JSON.generate(result)
''')
def ast(base):
 result=json.loads(subprocess.check_output(['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/ruby',str(parser),*[str(base/p) for p in paths]]))
 return {p:result[str(base/p)] for p in paths}
old_ast=ast(backup)
env=os.environ.copy();env.update(json.loads((tmp/'environment.json').read_text()))
for key in ('DATABASE_URL','REDIS_SENTINELS','BUNDLE_PATH','BUNDLE_GEMFILE','GEM_HOME','GEM_PATH'):env.pop(key,None)
command=['/Users/ghalyasaid/.rbenv/versions/3.4.4/bin/bundle','exec','rubocop','--force-exclusion','--only',','.join(cops),'-a',*paths,'--format','json','--out',str(tmp/'layout-only-autocorrect-results.json')]
with (tmp/'layout-only-autocorrect.log').open('w') as log:result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT)
new_ast=ast(root);mismatches=[p for p in paths if old_ast[p]!=new_ast[p]]
if mismatches:
 for p in mismatches:(root/p).write_bytes((backup/p).read_bytes())
 raise RuntimeError(f'AST-changing edits reverted: {mismatches}')
after=snapshot();git('update-ref','refs/r09/layout-only-after-source-20260912',after,'0'*40)
changed=git('diff','--name-only',before,after).splitlines();assert set(changed)<=set(paths)
proof={'before_tree':before,'after_tree':after,'allowed_cops':cops,'selected_paths':paths,'changed_paths':changed,'before_ast_sha256':old_ast,'after_ast_sha256':new_ast,'ast_mismatches':mismatches,'autocorrect_exit_code':result.returncode,'invocation':command}
(tmp/'layout-only-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({'before_tree':before,'after_tree':after,'selected_paths':len(paths),'changed_paths':len(changed),'ast_mismatches':len(mismatches),'exit_code':result.returncode}),flush=True)
