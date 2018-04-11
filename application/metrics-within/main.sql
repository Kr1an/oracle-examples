
set serveroutput on;

create or replace procedure console(v in char) is
begin
  dbms_output.put_line(v);
end;
/

create or replace procedure drop_table(table_name in char) is
  log_title varchar2(255) := 'DROP_TABLE';
begin
  execute immediate 'drop table ' ||  table_name;
  console(log_title || ': success drop for table with name: ' || table_name);
exception
  when others then
    if sqlcode != -942 then
      raise;
    end if;
    console(log_title || ': drop table for name: ' || table_name || ' was skiped. Table does not exist');
end;
/

begin
  drop_table('MetricJobLogs');
  drop_table('Metrics');
end;
/

begin
  dbms_scheduler.drop_job(job_name => 'metric_analize_job');
exception
  when others then
    return;
end;
/

create table MetricJobLogs (
  ts timestamp default current_timestamp,
  msg varchar2(500)
);

create table Metrics (
  name varchar2(255),
  metric_name varchar2(255),
  warn_number number,
  limit_number number
);

create or replace procedure metric_analize is
  metric_current_value number;
  sql_str varchar(255);
  xml_form varchar(5000);
  message varchar(255);
begin
  for metric in (select * from Metrics) loop
    execute immediate 'select ' || metric.metric_name || ' from v$sql where rownum = 1' into metric_current_value;
    console(metric.metric_name || ' is ' || metric_current_value);
    if metric_current_value > metric.warn_number or TRUE then
      message :=  'warning value is: ' || metric.warn_number ||  'limit value is: ' || metric.limit_number || '. Current value: ' || metric_current_value;
      send_email(
        '7633766@gmail.com',
        'kr1an@hotmail.com',
        'metric: ' || metric.metric_name || 'limit achived',
        message
      );
      xml_form := '<Report><Timestamp>' || current_timestamp || '</Timestamp><Message>' || message || '</Message></Report>';
      insert into MetricJobLogs (msg) values (xml_form);
    end if;
  end loop;
end;
/

create or replace procedure add_metric(
  name char,
  metric_name char,
  warn_number number,
  limit_number number
)
is
  sql_str varchar(255);
begin
  sql_str := 'insert into Metrics (name, metric_name, warn_number, limit_number) values(:1, :2, :3, :4)';
  execute immediate sql_str using name, metric_name, warn_number, limit_number;
end;
/

create or replace
procedure send_email(sender in varchar2, receiver in varchar2, subject in varchar2, text in varchar2) is
  res utl_http.resp;
  req utl_http.req;
  url varchar2(4000) := 'sender';
  content varchar2(4000) := '{"mail": {"from":"'||sender||'", "to":"'||receiver||'", "subject":"'||subject||'", "text":"'||text||'"}}';
begin
  req := utl_http.begin_request(url, 'POST',' HTTP/1.1');
  utl_http.set_header(req, 'content-type', 'application/json');
  utl_http.set_header(req, 'Content-Length', length(content));

  utl_http.write_text(req, content);
  res := utl_http.get_response(req);
  utl_http.end_response(res);
end;
/


BEGIN
  DBMS_NETWORK_ACL_ADMIN.append_host_ace (
    host => 'sender',
    lower_port => 80,
    upper_port => 8000,
    ace => xs$ace_type(
      privilege_list => xs$name_list('http'),
      principal_name => 'SYSTEM',
      principal_type => xs_acl.ptype_db
    )
  );
exception
  when others then
    return;
END;
/

begin
  add_metric(
    name => 'First Metric',
    metric_name => 'fetches',
    warn_number => 12,
    limit_number => 24
  );
  add_metric(
    name => 'First Metric',
    metric_name => 'sharable_mem',
    warn_number => 500000,
    limit_number => 650000
  );
end;
/

begin
   dbms_scheduler.create_job (
    job_name => 'metric_analize_job',
    job_type => 'PLSQL_BLOCK',
    job_action => 'metric_analize;',
    start_date => SYSTIMESTAMP,
    enabled => true,
    repeat_interval => 'FREQ=SECONDLY;INTERVAL=5'
   );
end;
/
