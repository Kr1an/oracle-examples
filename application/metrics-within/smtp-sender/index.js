var nodemailer = require('nodemailer');
var express = require('express');
var bodyParser = require('body-parser');
var app = express();

app.use(bodyParser.json())

var transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: '7633766@gmail.com',
    pass: 'WgANy766892'
  }
});

app.post('/', function(req, res) {
  console.log(req.body);
  var mailOptions = req.body.mail;
  transporter.sendMail(mailOptions, function(error, info){
    if (error) {
      console.log(error);
    } else {
      console.log('Email sent: ' + info.response);
    }
  });
  res.status(200);
  res.end();
})

app.listen(80);
