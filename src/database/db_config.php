<?php
$host = 'localhost';
$db = 'captive_portal';
$user = 'freebsd';
$pass = '123456';

try {
    $pdo = new PDO("pgsql:host=$host;dbname=$db", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Database connected successfully.";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage();
}
?>
