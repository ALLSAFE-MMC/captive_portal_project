<?php
session_start();
include 'db_config.php'; // Veritabanı bağlantı dosyası

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $username = $_POST['username'];
    $password = $_POST['password'];

    $result = pg_query_params($dbconn, 'SELECT * FROM users WHERE username = $1 AND password = crypt($2, password)', array($username, $password));
    if (pg_num_rows($result) == 1) {
        $_SESSION['username'] = $username;
        header("Location: success.php");
    } else {
        echo "Hatalı kullanıcı adı veya şifre.";
    }
}
?>
