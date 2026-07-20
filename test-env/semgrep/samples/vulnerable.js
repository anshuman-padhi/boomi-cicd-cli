// Deliberately vulnerable Boomi Data Process (JavaScript) script — verifies the
// Semgrep ruleset. NOT a real process. Do not deploy.
for (var i = 0; i < dataContext.getDataCount(); i++) {
  var props = dataContext.getProperties(i);
  var userInput = props.getProperty("dynamicdocument.DDP_expr");

  // hardcoded credential
  var token = "tok_live_abcdef0123456789";

  // dynamic code execution / injection
  var result = eval(userInput);
  var fn = new Function("return " + userInput);

  dataContext.storeStream(dataContext.getStream(i), props);
}
