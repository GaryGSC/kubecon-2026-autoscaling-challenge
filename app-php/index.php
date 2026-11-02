<?php
// Simulates a slow backend: waits (no CPU burn) a random time in [minWait, maxWait] ms (?minWait=A&maxWait=B).
$min = filter_var($_GET['minWait'] ?? 0, FILTER_VALIDATE_INT);
$max = filter_var($_GET['maxWait'] ?? 0, FILTER_VALIDATE_INT);
$min = $min === false ? 0 : max(0, min(30000, $min));
$max = $max === false ? 0 : max($min, min(30000, $max));
$ms = random_int($min, $max);
usleep($ms * 1000);
header('Content-Type: text/plain');
echo "waited {$ms}ms (pid " . getmypid() . ")\n";
