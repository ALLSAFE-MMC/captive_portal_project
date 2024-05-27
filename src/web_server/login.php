<?php
$username = $_POST['username'];
$password = $_POST['password'];

// Basit kimlik doğrulama
if ($username == 'admin' && $password == 'admin') {
    header('Location: success.php');
} else {
    echo 'Invalid credentials';
}
?>
