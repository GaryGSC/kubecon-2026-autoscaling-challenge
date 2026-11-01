<?php
// Simulates a slow backend: waits (no CPU burn) for ?ms=N milliseconds.
$ms = filter_var($_GET['ms'] ?? 0, FILTER_VALIDATE_INT);
$ms = $ms === false ? 0 : max(0, min(30000, $ms));
usleep($ms * 1000);
header('Content-Type: text/plain');
echo "waited {$ms}ms (pid " . getmypid() . ")\n";
