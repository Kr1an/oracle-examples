set serveroutput on;

begin
  DBMS_AQADM.DROP_QUEUE_TABLE(queue_table => 'system.connectusertable', force => TRUE);
end;
/

drop table Messages;
drop table Sessions;

create table Messages (
   author varchar2(20),
   message varchar2(50),
   created_at timestamp default systimestamp
);

create table Sessions (
   sid varchar2(50),
   author varchar2(20)
);

drop type AddMessagePayloadType force;
drop type ConnectUserPayloadType force;

create type AddMessagePayloadType as object(
   sid varchar2(50),
   message varchar2(50)
);
/

create type ConnectUserPayloadType as object(
   sid varchar2(50),
   author varchar2(20)
);
/

declare
   l_reginfo CQ_NOTIFICATION$_REG_INFO;
   l_cursor  SYS_REFCURSOR;
   l_regid   NUMBER;
begin
    l_reginfo := cq_notification$_reg_info (
        'query_callback',
        dbms_cq_notification.qos_query,
        0, 0, 0
    );

    l_regid := dbms_cq_notification.new_reg_start(l_reginfo);

    open l_cursor FOR
        select dbms_cq_notification.cq_notification_queryid,
            message,
            author
        from Messages;
    close l_cursor;

    dbms_cq_notification.reg_end;
end;
/

create or replace procedure connect_user(sid in varchar, author in varchar) as
begin
  execute immediate 'insert into Sessions (sid, author) values (:1, :2)' using sid, author;
end;
/

create or replace procedure send_message(sid in varchar2, message in varchar2) as
  author Sessions.author%type;
  cnt number;
  sql_str varchar2(255);
begin
  sql_str := 'select author from Sessions where sid=''' || sid || '''';
  execute immediate sql_str into author;
  execute immediate 'insert into Messages (message, author) VALUES (:1, :2)' using message, author;
end;
/

create or replace function get_messages return varchar2 as
  author Messages.author%type;
  message Messages.message%type;
  result varchar2(5000) := '';
begin
  for message in (select author, message from Messages order by created_at) loop

    result := result || '{"author": "' || message.author || '", "message": "' || message.message || '"},';
  end loop;
  return '[' || TRIM(TRAILING ',' FROM result) || ']';
end;
/



begin
  connect_user('hello world', 'anton');
  connect_user('hello world1', 'anton1');
  send_message('hello world', 'message 1');
  send_message('hello world1', 'message 2');
  dbms_output.put_line(get_messages());
end;
/

begin
  dbms_aqadm.create_queue_table(queue_table => 'system.connectusertable', queue_payload_type => 'ConnectUserPayloadType', multiple_consumers => true);
  dbms_aqadm.create_queue( queue_name => 'system.ConnectUserQueue', queue_table => 'system.connectusertable' );
  dbms_aqadm.start_queue(queue_name=>'system.ConnectUserQueue');
  dbms_aqadm.add_subscriber( queue_name => 'system.ConnectUserQueue', subscriber => sys.aq$_agent('RECIPIENT', NULL, NULL) );
  dbms_aq.register(sys.aq$_reg_info_list(sys.aq$_reg_info( 'system.ConnectUserQueue:RECIPIENT', dbms_aq.namespace_aq, 'plsql://p_dequeue', HEXTORAW('FF'))), 1);

END;
/

create or replace PROCEDURE query_callback(ntfnds IN CQ_NOTIFICATION$_DESCRIPTOR) AS
  l_req  utl_http.req;
  l_resp utl_http.resp;
begin
    l_req := utl_http.begin_request(url => '192.168.0.1:3000/db', method => 'GET');
    l_resp := utl_http.get_response(r => l_req);
    utl_http.end_response(r => l_resp);
END;
/


CREATE OR REPLACE PROCEDURE p_enqueue(sid IN VARCHAR2, author in varchar2)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  enqueue_options       dbms_aq.enqueue_options_t;
  message_properties    dbms_aq.message_properties_t;
  message_handle        RAW(16);
BEGIN
  dbms_aq.enqueue( queue_name            => 'system.ConnectUserQueue',
                   enqueue_options       => enqueue_options,
                   message_properties    => message_properties,
                   payload               => ConnectUserPayloadType(sid, author),
                   msgid                 => message_handle);
  COMMIT;
END;
/


CREATE OR REPLACE PROCEDURE p_dequeue_manual
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  dequeue_options      dbms_aq.dequeue_options_t;
  message_properties   dbms_aq.message_properties_t;
  message_handle       RAW(16);
  message              ConnectUserPayloadType;
BEGIN
  dequeue_options.dequeue_mode := DBMS_AQ.REMOVE;
  dequeue_options.wait := DBMS_AQ.no_wait;
  dbms_aq.dequeue( queue_name => 'system.ConnectUserQueue',
                   dequeue_options       => dequeue_options,
                   message_properties    => message_properties,
                   payload               => message,
                   msgid                 => message_handle);
  dbms_output.put_line('sid: ' || message.sid);
  -- dbms_output.put_line('msg: ' || message.author);
  COMMIT;
END p_dequeue_manual;
/


CREATE OR REPLACE PROCEDURE p_dequeue ( context raw,
                                        reginfo sys.aq$_reg_info,
                                        descr sys.aq$_descriptor,
                                        payload raw,
                                        payloadl number)
as
 dequeue_options    dbms_aq.dequeue_options_t;
 message_properties dbms_aq.message_properties_t;
 message_handle     RAW(16);
 message            ConnectUserPayloadType;
BEGIN
   dequeue_options.msgid         := descr.msg_id;
   dequeue_options.consumer_name := descr.consumer_name;

   dbms_aq.dequeue(queue_name => descr.queue_name,
                   dequeue_options => dequeue_options,
                   message_properties => message_properties,
                   payload => message,
                   msgid => message_handle);

   INSERT INTO sessions (sid, author) VALUES (message.sid, message.author);

   COMMIT;
END;
/

