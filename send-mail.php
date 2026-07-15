#!/usr/bin/env php
<?php

$opts    = getopt('t:s:f:');
$to      = $opts['t'] ?? null;
$subject = $opts['s'] ?? null;
$from    = $opts['f'] ?? null;
$body    = stream_get_contents(STDIN);

$host = getenv('SMTP_HOST') ?: '';
$port = getenv('SMTP_PORT') ?: '465';
$user = getenv('SMTP_USER') ?: '';
$pass = getenv('SMTP_PASS') ?: '';

if (!$to || !$subject || !$host || !$user || !$pass) {
    fwrite(STDERR, "Usage: send-mail.php -t <to> -s <subject> [-f <from>]\n");
    fwrite(STDERR, "Requires env: SMTP_HOST, SMTP_USER, SMTP_PASS [, SMTP_PORT]\n");
    exit(1);
}

$from = $from ?: $user;

$ctx    = stream_context_create(['ssl' => ['verify_peer' => true, 'verify_peer_name' => true]]);
$scheme = in_array((int)$port, [587, 2525]) ? 'tcp' : 'ssl';
$socket = stream_socket_client("{$scheme}://{$host}:{$port}", $errno, $errstr, 10, STREAM_CLIENT_CONNECT, $ctx);

if (!$socket) {
    fwrite(STDERR, "SMTP connection failed ({$host}:{$port}): {$errstr}\n");
    exit(1);
}

function smtp_read($socket) {
    $buf = '';
    while ($line = fgets($socket, 512)) {
        $buf .= $line;
        if (strlen($line) < 4 || $line[3] === ' ') break;
    }
    return $buf;
}

function smtp_cmd($socket, $cmd, $expect) {
    fwrite($socket, $cmd . "\r\n");
    $r = smtp_read($socket);
    if ((int) substr($r, 0, 3) !== $expect) {
        fwrite(STDERR, "SMTP error (expected {$expect}): {$r}");
        return false;
    }
    return true;
}

smtp_read($socket); // banner
if (!smtp_cmd($socket, 'EHLO localhost', 250)) exit(1);

// Port 587: upgrade to TLS via STARTTLS before AUTH
if ($scheme === 'tcp') {
    if (!smtp_cmd($socket, 'STARTTLS', 220)) exit(1);
    if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
        fwrite(STDERR, "STARTTLS negotiation failed\n");
        exit(1);
    }
    if (!smtp_cmd($socket, 'EHLO localhost', 250)) exit(1);
}

if (!smtp_cmd($socket, 'AUTH LOGIN',            334)) exit(1);
if (!smtp_cmd($socket, base64_encode($user),    334)) exit(1);
if (!smtp_cmd($socket, base64_encode($pass),    235)) exit(1);
if (!smtp_cmd($socket, "MAIL FROM:<{$from}>",   250)) exit(1);
if (!smtp_cmd($socket, "RCPT TO:<{$to}>",       250)) exit(1);

fwrite($socket, "DATA\r\n");
if ((int) substr(smtp_read($socket), 0, 3) !== 354) {
    fwrite(STDERR, "SMTP DATA rejected\n");
    exit(1);
}

$data  = "Date: " . date('r') . "\r\n";
$data .= "From: {$from}\r\n";
$data .= "To: {$to}\r\n";
$data .= "Subject: =?UTF-8?B?" . base64_encode($subject) . "?=\r\n";
$data .= "MIME-Version: 1.0\r\n";
$data .= "Content-Type: text/plain; charset=UTF-8\r\n";
$data .= "Content-Transfer-Encoding: base64\r\n";
$data .= "\r\n";
$data .= chunk_split(base64_encode($body));
$data .= "\r\n.";

fwrite($socket, $data . "\r\n");
$r = smtp_read($socket);
if ((int) substr($r, 0, 3) !== 250) {
    fwrite(STDERR, "SMTP send error: {$r}");
    fclose($socket);
    exit(1);
}

smtp_cmd($socket, 'QUIT', 221);
fclose($socket);
