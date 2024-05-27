<?php
$dbconn = pg_connect("host=localhost dbname=captive_portal user=postgres password=123456")
    or die('Veritabanına bağlanılamadı: ' . pg_last_error());
?>
