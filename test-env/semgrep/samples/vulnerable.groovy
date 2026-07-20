// Deliberately vulnerable Boomi Data Process (Groovy) script — used to verify the
// Semgrep ruleset fires. NOT a real process. Do not deploy.
import groovy.sql.Sql
import javax.crypto.Cipher

for (int i = 0; i < dataContext.getDataCount(); i++) {
    def props = dataContext.getProperties(i)
    def userInput = props.getProperty("dynamicdocument.DDP_id")

    // hardcoded credential
    def password = "SuperSecretP@ss123"
    def apiKey = "ak_live_9f8e7d6c5b4a3210"

    // SQL injection via string concatenation
    def sql = Sql.newInstance("jdbc:mysql://db/app", "root", password)
    def rows = sql.rows("SELECT * FROM orders WHERE id = '" + userInput + "'")

    // OS command execution with untrusted input
    "ping " + userInput execute()
    Runtime.getRuntime().exec("sh -c 'cleanup " + userInput + "'")

    // XXE — parser without entity hardening
    def parsed = new XmlSlurper().parseText(new String(dataContext.getStream(i).bytes))

    // weak crypto
    def c = Cipher.getInstance("DES")
    def md = java.security.MessageDigest.getInstance("MD5")

    dataContext.storeStream(dataContext.getStream(i), props)
}
