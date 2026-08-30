<?php
declare(strict_types=1);

// Security router for PHP's built-in development server. Without a router,
// `php -S` serves unknown extensions as static files, including admin/.env.
$requestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
$requestPath = is_string($requestPath) ? rawurldecode($requestPath) : '';
$requestPath = str_replace('\\', '/', $requestPath);
$segments = array_values(array_filter(explode('/', $requestPath), 'strlen'));
$firstSegment = strtolower((string) ($segments[0] ?? ''));
$fileName = strtolower((string) end($segments));
$hasHiddenSegment = count(array_filter(
    $segments,
    static fn (string $segment): bool => str_starts_with($segment, '.')
)) > 0;

$hasUnsafePath = $requestPath === ''
    || str_contains($requestPath, "\0")
    || preg_match('#(?:^|/)\.\.?(?:/|$)#', $requestPath) === 1;
$isPrivatePath = $hasHiddenSegment
    || in_array(
        $firstSegment,
        ['config', 'includes', 'services', 'tests'],
        true
    );
$isPrivateFile = $fileName === 'router.php';

if ($hasUnsafePath || $isPrivatePath || $isPrivateFile) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    header('Cache-Control: no-store');
    echo 'Not found.';
    return true;
}

if ($requestPath === '/') {
    require __DIR__ . '/index.php';
    return true;
}

// Let the development server execute public PHP pages and serve public assets.
return false;
