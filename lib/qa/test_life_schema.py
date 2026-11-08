import sqlite3,re
from pathlib import Path
r=Path(__file__).resolve().parent.parent
tables=(r/'services/db/db_tables.dart').read_text()
migr=(r/'services/db/db_migrations.dart').read_text()
names=['family_trees','family_members','family_relationships','family_memories','family_member_photos','family_memory_photos','family_memory_people','life_connections','life_events','life_event_people']
stmts=[]
for name in names:
 p=re.search(r'CREATE TABLE IF NOT EXISTS '+name+r'\s*\([\s\S]*?\n\)\n\'\'\'',tables)
 assert p, name
 stmts.append((name, p.group().removesuffix("\n'''")))
indexes=['idx_life_connections_tree','idx_life_events_tree_date','idx_life_event_people_person','idx_family_memory_event']
idx_stmts=[]
for name in indexes:
 p=re.search(r'CREATE INDEX IF NOT EXISTS '+name+r'\s*[\s\S]*?\n\'\'\'',migr)
 assert p,name
 idx_stmts.append(p.group().removesuffix("\n'''"))

def setup(old=False):
 db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
 for name,st in stmts:
  if old and name in ['life_connections','life_events','life_event_people']:continue
  if old and name=='family_memories':st=st.replace('  event_id INTEGER,\n','').replace('  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE,\n  FOREIGN KEY (event_id) REFERENCES life_events(id) ON DELETE SET NULL','  FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE')
  db.execute(st)
 if old:
  for name,st in stmts:
   if name.startswith('life_'):db.execute(st)
  db.execute('ALTER TABLE family_memories ADD COLUMN event_id INTEGER')
 for sql in idx_stmts: db.execute(sql)
 return db

for old in (False,True):
 db=setup(old)
 scenario='v20 upgrade' if old else 'fresh v21'
 cols=[r[1] for r in db.execute('PRAGMA table_info(family_memories)')]
 assert 'event_id' in cols
 db.execute('INSERT INTO family_trees (id,name,created_at,updated_at) VALUES(1,"Me","n","n")')
 db.execute('INSERT INTO family_trees (id,name,created_at,updated_at) VALUES(2,"Other","n","n")')
 for id in (1,2): db.execute('INSERT INTO family_members (id,tree_id,first_name,created_at,updated_at) VALUES(?,1,?,?,?)',(id,'P'+str(id),'n','n'))
 db.execute('INSERT INTO life_connections (tree_id,from_member_id,to_member_id,connection_type,created_at,updated_at) VALUES(1,1,2,"friend","n","n")')
 try:
  db.execute('INSERT INTO life_connections (tree_id,from_member_id,to_member_id,connection_type,created_at,updated_at) VALUES(1,1,2,"friend","n","n")');raise AssertionError('duplicate allowed')
 except sqlite3.IntegrityError:pass
 db.execute('INSERT INTO life_events (id,tree_id,title,event_type,created_at,updated_at) VALUES(100,1,"Day trip","travel","n","n")')
 db.execute('INSERT INTO life_event_people (event_id,member_id) VALUES(100,1)')
 db.execute('INSERT INTO family_memories (id,tree_id,member_id,title,event_id,created_at,updated_at) VALUES(5,1,1,"Photos",100,"n","n")')
 assert db.execute('SELECT event_id FROM family_memories WHERE id=5').fetchone()[0]==100
 db.execute('UPDATE family_memories SET event_id=NULL WHERE id=5')
 db.execute('DELETE FROM life_event_people WHERE event_id=100');db.execute('DELETE FROM life_events WHERE id=100')
 assert db.execute('SELECT COUNT(*) FROM family_memories WHERE id=5').fetchone()[0]==1
 db.execute('DELETE FROM family_trees WHERE id=1')
 assert db.execute('SELECT COUNT(*) FROM life_connections').fetchone()[0]==0
 assert db.execute('SELECT COUNT(*) FROM life_events').fetchone()[0]==0
 assert db.execute('SELECT COUNT(*) FROM family_memories').fetchone()[0]==0
 print('PASS',scenario,'10 related tables, migration, indexes, album/event linking, unique connections, cascade safety')
