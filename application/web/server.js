const
  app = require('express')(),
  server = require('http').createServer(app),
  bodyParser = require('body-parser'),
  cookieParser = require('cookie-parser'),
  logger = require('morgan'),
  serveStatic = require('serve-static'),
  oracledb = require('oracledb'),
  io = require('socket.io').listen(server);


server.listen(3000);
oracledb.autoCommit = true;
const dbConfig = {
  user: 'hr',
  password: 'oracle',
  connectString: 'localhost:1521/xe',
};

const sid = () => (req, res, next) => {
  // // TODO: change random value algorithm generation
  // console.log('here');
  // if (req.cookies.sid) {
  //   return next();
  // }
  // console.log('sid: ', req.cookies);
  // res.cookie('sid', hash);
  // req.cookies.sid = hash;
  // console.log('after sid: ', req.cookies);
  return next();
}

const socketConnection = (sock) => {
  sock.on('test', function(){ console.log(" test")});
  console.log('socket connection');
}

const connect = async (req, res) => {
  const sid = `${Date.now()}`;
  res.cookie('sid', sid);
  const { author } = req.body
  try {
    console.log('connect: ', sid, author);
    const conn = await oracledb.getConnection(dbConfig);
    const result = await conn.execute("BEGIN connect_user(:sid, :author); END;", { sid, author });
    console.log('after connect: ', sid, author);
    conn.release();
    res
      .status(200)
      .jsonp({ message: 'User Registered' });
  } catch (e) {
    res
      .status(500)
      .jsonp({ message: 'Connection is not established' });
  }
}

const sendMessage = async (req, res) => {
  const { message } = req.body;
  const { sid } = req.cookies;
  try {
    console.log('sendMessage', message, sid);
    const conn = await oracledb.getConnection(dbConfig);
    const result = await conn.execute("BEGIN send_message(:sid, :message); END;", { sid, message });
    console.log('after sendMessage', message, sid);
    conn.release();
    res
      .status(200)
      .jsonp({ message: 'Message submitted' });
  } catch (e) {
    console.log(e);
    res
      .status(500)
      .jsonp({ message: 'Can not post message' });
  }
}

io.on('connection', socketConnection);

const dbRefresh = async (req, res) => {
  try {
    const conn = await oracledb.getConnection(dbConfig);
    const result = await conn.execute(
      "BEGIN :ret := get_messages; END;",
      {ret: {dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 5000}}
    );
    io.emit('refresh', JSON.parse(result.outBinds.ret));
    conn.release();
    res.end('', 200);
  } catch (e) {
    res
      .status(500)
      .jsonp({ message: 'Can not update Messages' });
  }
}


app
  .use(bodyParser.json())
  .use(bodyParser.urlencoded({ extended: false }))
  .use(cookieParser())
  .use(sid())
  .use('/', serveStatic(__dirname + '/public'))
  .use('/vendor', serveStatic(__dirname + '/bower_components'))
  .get('/db', dbRefresh)
  .post('/connect', connect)
  .post('/send-message', sendMessage);
