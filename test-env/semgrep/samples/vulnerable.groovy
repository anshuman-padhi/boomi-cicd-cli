// Deliberately vulnerable Boomi Data Process (Groovy) script — used to verify the
// Semgrep ruleset fires across all classes. NOT a real process. Do not deploy.
import groovy.sql.Sql
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.IvParameterSpec

for (int i = 0; i < dataContext.getDataCount(); i++) {
    def props = dataContext.getProperties(i)
    def userInput = props.getProperty("dynamicdocument.DDP_id")

    // hardcoded credentials
    def password = "SuperSecretP@ss123"
    def apiKey = "ak_live_9f8e7d6c5b4a3210"
    println("connecting with password=" + password)          // secret written to logs

    // SQL injection via string concatenation
    def sql = Sql.newInstance("jdbc:mysql://db/app", "root", password)
    def rows = sql.rows("SELECT * FROM orders WHERE id = '" + userInput + "'")

    // OS command execution with untrusted input
    ("ping " + userInput).execute()
    Runtime.getRuntime().exec("sh -c 'cleanup " + userInput + "'")

    // dynamic Groovy code execution (code injection)
    def gs = new GroovyShell()
    gs.evaluate("return " + userInput)
    Eval.me(userInput)

    // XXE — parser without entity hardening
    def parsed = new XmlSlurper().parseText(new String(dataContext.getStream(i).bytes))

    // insecure deserialization
    def ois = new ObjectInputStream(dataContext.getStream(i))
    def obj = ois.readObject()

    // SSRF — URL built from input
    def conn = new URL("http://internal/" + userInput).openConnection()

    // path traversal — file path from input
    def f = new File("/data/" + userInput)

    // LDAP injection
    ctx.search("ou=users", "(uid=" + userInput + ")", controls)

    // weak crypto + hardcoded key/IV
    def c = Cipher.getInstance("DES/ECB/PKCS5Padding")
    def md = java.security.MessageDigest.getInstance("MD5")
    def key = new SecretKeySpec("0123456789abcdef".getBytes(), "AES")
    def iv = new IvParameterSpec("1234567890123456".getBytes())

    // insecure randomness for a security value
    def token = new Random().nextInt(999999)

    // XPath injection
    def xp = javax.xml.xpath.XPathFactory.newInstance().newXPath()
    def hit = xp.evaluate("/users/user[@id='" + userInput + "']", doc)

    // disabled TLS verification (accept-all trust manager)
    def tm = new javax.net.ssl.X509TrustManager() {
        void checkServerTrusted(java.security.cert.X509Certificate[] c, String a) {}
        void checkClientTrusted(java.security.cert.X509Certificate[] c, String a) {}
        java.security.cert.X509Certificate[] getAcceptedIssuers() { return null }
    }

    dataContext.storeStream(dataContext.getStream(i), props)
}
