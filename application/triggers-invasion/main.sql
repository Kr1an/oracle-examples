set serveroutput on;

begin
  execute immediate 'drop table Students';
exception
  when others then
    if sqlcode != 942 then
      raise;
    else
      null;
    end if;
end;
/

begin
  execute immediate 'drop table Groups';
exception
  when others then
    if sqlcode != 942 then
      raise;
    else
      null;
    end if;
end;
/

begin
  execute immediate 'drop table StudentLogs';
exception
  when others then
    if sqlcode != 942 then
      raise;
    else
      null;
    end if;
end;
/

create table Students (id number, name varchar2(255), group_id number);
create table Groups (id number, name varchar2(255), c_val number default 0);
create table StudentLogs (
  old_id number,
  old_name varchar2(255),
  old_group_id number,
  new_id number,
  new_name varchar2(255),
  new_group_id number,
  action_type varchar2(255),
  action_date timestamp
);

begin
  execute immediate 'create table ActivityLogs(user_name varchar2(255), activity_title varchar2(255), activity_date date)';
exception
    when others then
      if sqlcode = -955 then
        null;
      else
         raise;
      end if;
END;
/

create or replace procedure output_student_logs is
  cursor student_logs_select_all is
    select old_id, old_name, old_group_id, new_id, new_name, new_group_id, action_date, action_type from StudentLogs;
  old_id StudentLogs.old_id%type;
  old_name StudentLogs.old_name%type;
  old_group_id StudentLogs.old_group_id%type;
  new_id StudentLogs.new_id%type;
  new_name StudentLogs.new_name%type;
  new_group_id StudentLogs.new_group_id%type;
  action_date StudentLogs.action_date%type;
  action_type StudentLogs.action_type%type;
begin
  open student_logs_select_all;
  loop
    fetch student_logs_select_all into old_id, old_name, old_group_id, new_id, new_name, new_group_id, action_date, action_type;
    exit when student_logs_select_all%notfound;
    logs('{ old_id: '
      || old_id
      || ', old_name: '
      || old_name
      || ', old_group_id: '
      || old_group_id
      || ', new_id: '
      || new_id
      || ', new_name: '
      || new_name
      || ', new_group_id: '
      || new_group_id
      || ', action_date: '
      || action_date
      || ', action_type: '
      || action_type
      || ' }');

  end loop;
end;
/

create or replace procedure output_groups is
  cursor groups_select_all is
    select id, name, c_val from Groups;
  id Groups.id%type;
  name Groups.name%type;
  c_val Groups.c_val%type;
begin
  open groups_select_all;
  loop
    fetch groups_select_all into id, name, c_val;
    exit when groups_select_all%notfound;
    logs('{ id: '
      || id
      || ', name: '
      || name
      || ', c_val: '
      || c_val
      || ' }');
  end loop;
end;
/

create or replace procedure output_students is
  cursor students_select_all is
    select id, name, group_id from Students;
  id Students.id%type;
  name Students.name%type;
  group_id Students.group_id%type;
begin
  open students_select_all;
  loop
    fetch students_select_all into id, name, group_id;
    exit when students_select_all%notfound;
    logs('{ id: '
      || id
      || ', name: '
      || name
      || ', group_id: '
      || group_id
      || ' }');
  end loop;
end;
/

create or replace procedure output_logs is
  cursor logs_select_all is
    select user_name, activity_title, activity_date from ActivityLogs;
  user_name ActivityLogs.user_name%type;
  activity_title ActivityLogs.activity_title%type;
  activity_date ActivityLogs.activity_date%type;
begin
  open logs_select_all;
  loop
    fetch logs_select_all into user_name, activity_title, activity_date;
    exit when logs_select_all%notfound;
    logs('{ user_name: '
      || user_name
      || ', activity_title: '
      || activity_title
      || ', activity_date: '
      || activity_date
      || ' }');
  end loop;
end;
/


create or replace procedure insert_log(user_name in ActivityLogs.user_name%type, activity_title in ActivityLogs.activity_title%type, activity_date in ActivityLogs.activity_date%type) is
begin
  execute immediate 'insert into ActivityLogs (user_name, activity_title, activity_date) values (:1, :2, :3)' using user_name, activity_title, activity_date;
end;
/

create or replace trigger logon_trigger
after logon on schema
begin
  insert_log(user, 'logon', sysdate);
end;
/

create or replace procedure logs(msg in char) is
begin
  dbms_output.put_line(msg);
end;
/

create or replace trigger validate_unique_student_id
before insert on Students
for each row
declare
  id_count number;
begin
  select count(*) into id_count from Students where id = :new.id;
  if id_count > 0 then
    raise_application_error(-20010, 'id is not unique');
  end if;
end;
/

create or replace trigger validate_unique_group_id
before insert or update of id on Groups
for each row
declare
  id_count number;
begin
  select count(*) into id_count from Groups where id = :new.id;
  if id_count > 0 then
    raise_application_error(-20010, 'id is not unique');
  end if;
end;
/

create or replace trigger validate_unique_group_name
before insert or update of name on Groups
for each row
declare
  name_count number;
begin
  select count(*) into name_count from Groups where name = :new.name;
  if name_count > 0 then
    raise_application_error(-20010, 'name is not unique');
  end if;
end;
/

create or replace trigger generate_student_id
before insert on Students
for each row
declare
  next_id number;
begin
  select max(id) + 1 into next_id from Students;
  if next_id is null then
    next_id := 1;
  end if;
  if :new.id is null then
    :new.id := next_id;
  end if;
end;
/

create or replace trigger generate_group_id
before insert on Groups
for each row
declare
  next_id number;
begin
  select max(id) + 1 into next_id from Groups;
  if next_id is null then
    next_id := 1;
  end if;
  if :new.id is null then
    :new.id := next_id;
  end if;
end;
/

create or replace trigger cascade_del
before delete on Groups
for each row
begin
  update Students set group_id = -2
  where group_id = :old.id;

  delete from Students where group_id = -2;
end;
/

create or replace trigger c_val_group_update
before insert or update or delete of group_id on Students
for each row
begin
  if updating and :new.group_id = -2 then
    return;
  end if;
  if deleting and :old.group_id = -2 then
    return;
  end if;
  if :old.group_id is not null then
    update Groups set c_val = c_val - 1 where id = :old.group_id;
  end if;
  if :new.group_id is not null then
    update Groups set c_val = c_val + 1 where id = :new.group_id;
  end if;
end;
/

create or replace trigger student_logger
after insert or update or delete on Students
for each row
declare
  action_type StudentLogs.action_type%type;
begin
  if inserting then
    action_type := 'c';
  elsif updating then
    action_type := 'u';
  elsif deleting then
    action_type := 'd';
  end if;
  insert into StudentLogs (old_id, old_name, old_group_id, new_id, new_name, new_group_id, action_type, action_date)
  values (:old.id, :old.name, :old.group_id, :new.id, :new.name, :new.group_id, action_type, current_timestamp);
  -- logs('type: ' || action_type);
  -- logs('old id: ' || :old.id);
  -- logs('old name: ' || :old.name);
  -- logs('old group_id: ' || :old.group_id);
  -- logs('new id: ' || :new.id);
  -- logs('new name: ' || :new.name);
  -- logs('new group_id: ' || :new.group_id);
end;
/

create or replace procedure undo(timestamp_moment in timestamp, value in varchar2 default '0', interval_type in varchar2 default 'second') is
  left_limit timestamp;
  right_limit timestamp;
  tmp_limit timestamp;
  tmp number;
begin
  left_limit := timestamp_moment + numtodsinterval(value, interval_type);
  right_limit := timestamp_moment;

  if left_limit > right_limit then
    tmp_limit := left_limit;
    left_limit := right_limit;
    right_limit := tmp_limit;
  end if;

  -- logs('left: ' || left_limit);
  -- logs('right: ' || right_limit);

  for action_log in (select * from StudentLogs where action_date between left_limit and right_limit order by action_date desc) loop
    execute immediate 'alter trigger student_logger disable';
      logs('type: ' || action_log.action_type);
      if action_log.action_type = 'u' then
        update Students set id = action_log.old_id, name = action_log.old_name, group_id = action_log.old_group_id where id = action_log.new_id;
      end if;
      if action_log.action_type = 'd' then
        insert into Students (id, name, group_id) values (action_log.old_id, action_log.old_name, action_log.old_group_id);
      end if;
      if action_log.action_type = 'c' then
        delete from Students where id = action_log.new_id;
      end if;
    execute immediate 'alter trigger student_logger enable';
  end loop;
  logs('tmp: ' || tmp);
end;
/

begin
  output_logs;

  insert into Groups (id, name) values (5, 'group1');
  insert into Groups (id, name) values (1, 'group2');
  insert into Groups (name) values ('Unknown4');
  insert into Groups (name) values ('Unknown6');
  output_groups;

  insert into Students (id, name, group_id) values (5, 'Unknown', 5);
  insert into Students (id, name) values (1, 'Unknown1');
  insert into Students (name) values ('Unknown2');
  insert into Students (name) values ('Unknown3');
  output_students;

  logs('add student with group_id: 5 name: Unknown');
  insert into Students (name, group_id) values ('Unknown', 5);
  output_students;

  logs('cascade delete groud with id: 5 so do student with name Unknown');
  delete from Groups where id = 5;
  logs('groups:');
  output_groups;
  logs('students');
  output_students;

  logs('create group(name: testUpdate, id: 100; name testUpdate2, id: 101;) user(name: testUser1, id: 100)');
  insert into Groups (id, name) values (100, 'testUpdate1');
  insert into Groups (id, name) values (101, 'testUpdate2');
  insert into Students (id, name, group_id) values (100, 'testUser1', 100);
  logs('students: ');
  output_students;

  update Students set group_id = 101 where id = 100;
  logs('groups:');
  output_groups;
  logs('students');
  output_students;

  insert into Students (name, group_id) values ('Unknown', 100);
  insert into Students (name, group_id) values ('Unknown1', 101);
  insert into Students (name, group_id) values ('Unknown2', 100);
  insert into Students (name, group_id) values ('Unknown3', 100);

  logs('groups:');
  output_groups;

  delete from Students where group_id = 100;
  logs('groups:');
  output_groups;

  logs('students:');
  output_students;

  dbms_lock.sleep(2);

  delete from Students where id = 100;
  update Students set group_id = 100 where id = 102;
  insert into Students (id, name, group_id) values (1000, 'TEST', 100);

  logs('groups:');
  output_groups;

  logs('students:');
  output_students;

  undo(current_timestamp, '-1', 'second');

  logs('students:');
  output_students;
end;
/
