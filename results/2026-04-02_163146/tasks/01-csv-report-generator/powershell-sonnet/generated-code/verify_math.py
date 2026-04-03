employees = [
    ('Alice Johnson',   'Engineering', 95000,  'active'),
    ('Bob Smith',       'Marketing',   72000,  'active'),
    ('Carol White',     'Engineering', 105000, 'active'),
    ('David Brown',     'HR',          68000,  'inactive'),
    ('Eve Davis',       'Marketing',   78000,  'active'),
    ('Frank Miller',    'Engineering', 88000,  'inactive'),
    ('Grace Wilson',    'HR',          71000,  'active'),
    ('Henry Moore',     'Marketing',   65000,  'active'),
    ('Iris Taylor',     'Engineering', 112000, 'active'),
    ('Jack Anderson',   'HR',          69000,  'inactive'),
    ('Kate Thomas',     'Engineering', 98000,  'active'),
    ('Liam Jackson',    'Marketing',   75000,  'active'),
]
active = [(n,d,s) for n,d,s,st in employees if st == 'active']
print(f'Total records: {len(employees)}')
print(f'Active count: {len(active)}')
from collections import defaultdict
depts = defaultdict(list)
for n,d,s in active:
    depts[d].append(s)
for dept, salaries in sorted(depts.items()):
    avg = sum(salaries)/len(salaries)
    print(f'{dept}: count={len(salaries)}, avg={avg:.2f}')
salaries = [s for _,_,s in active]
print(f'Overall avg: {sum(salaries)/len(salaries):.2f}')
print(f'Min: {min(salaries)}, Max: {max(salaries)}')
