set serveroutput on;

drop table MyTable;
create table MyTable (id number, val number);

create or replace procedure logger(msg in char) is
begin
  dbms_output.put_line(msg);
end;
/

create or replace function generate_insert_statement(id in number, val in number) return char is
begin
  return 'insert into MyTable (id, val) values (' || id || ',' || val || ')';
end;
/

create or replace procedure delete_operation(id in number) is
begin
  EXECUTE IMMEDIATE 'delete from MyTable where id = :1' using id;
end;
/

create or replace procedure update_operation(id in number, val in number) is
begin
  EXECUTE IMMEDIATE 'update MyTable set val = :2 where id = :1' using id, val;
end;
/

create or replace procedure insert_operation(id in number, val in number) is
begin
  EXECUTE IMMEDIATE 'insert into MyTable (id, val) values (:1, :2)' using id, val;
end;
/

create or replace function num_random(mod_power in number default 4) return number is
  rand_value number;
begin
  select round(dbms_random.value(power(10, mod_power - 1), power(10, mod_power) - 1))
  into rand_value
  from dual;

  return rand_value;
end num_random;
/

create or replace procedure populate_with_rand(rows_to_create in number default 10) is
  tmp_id number;
  tmp_val number;
begin
  for i in 1..rows_to_create loop
    tmp_id:= num_random();
    tmp_val:= num_random();
    insert_operation(tmp_id, tmp_val);
  end loop outer_loop;
end;
/

create or replace procedure odd_even_analize is
  odd_count number;
  even_count number;
  diff number;
  msg varchar2(10);
begin
  select count(*)
  into odd_count
  from MyTable
  where mod(val, 2) = 1;

  select count(*)
  into even_count
  from MyTable
  where mod(val, 2) = 0;

  diff := odd_count - even_count;

  if diff > 0 then
    msg := 'TRUE';
  elsif diff < 0 then
    msg := 'FALSE';
  else
    msg := 'EQUAL';
  end if;
  logger(msg);
end;
/

create or replace procedure output_rows is
  cursor cursor_select_all is
    select id, val from MyTable;
  id MyTable.id%type;
  val MyTable.val%type;
begin
  open cursor_select_all;
  loop
    fetch cursor_select_all into id, val;
    exit when cursor_select_all%notfound;
    logger('{ id: ' || id || ', val: ' || val || ' }');
  end loop;
  close cursor_select_all;
end;
/

create or replace function calc_year_income(month_income in number, bonus_percent in number) return number is
  income number;
  not_integer_percent exception;
begin
  if bonus_percent > 100 or bonus_percent < 0 then
    raise not_integer_percent;
  end if;

  income := (1 + bonus_percent) * 12 * month_income;
  return income;
exception
  when not_integer_percent then
    logger('invalid percentage');
    return -1;
end;
/

declare
  ROWS_TO_ADD number := 10;
  rowsCount number;
begin
  logger('populated MyTable');
  populate_with_rand;
  output_rows;

  logger('odd event analyzer');
  odd_even_analize;

  logger('generating insert statement');
  logger(generate_insert_statement(0, 0));


  logger('inserting operation id: 4, val: 2');
  insert_operation(4, 2);
  output_rows;

  logger('updating operation id: 4, val: 4');
  update_operation(4, 4);
  output_rows;

  logger('deleting operation id: 4');
  delete_operation(4);
  output_rows;

  logger('calculating year income');
  logger(calc_year_income(1200, 12.3));

  logger('calculating year income with Error');
  logger(calc_year_income(1200, -12.3));
end;
/
