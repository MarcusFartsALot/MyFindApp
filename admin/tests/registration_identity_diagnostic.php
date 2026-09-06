<?php
declare(strict_types=1);

// Read-only schema inspection. Never reads identity values or writes records.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once dirname(__DIR__) . '/config/supabase.php';

try {
    $schema = (new SupabaseClient())->asService('GET', '/rest/v1/');
    $result = ['schema_reachable' => true];
    foreach (['citizens' => 'ic_number', 'tourists' => 'passport_number'] as $table => $column) {
        $properties = $schema['definitions'][$table]['properties'] ?? [];
        $result[$table] = ['identity_column_present' => isset($properties[$column])];
    }
    $result['identity_availability_function_present'] = isset(
        $schema['paths']['/rpc/module400_registration_identity_available']
    );
    $result['registration_function_present'] = isset(
        $schema['paths']['/rpc/submit_registration_application']
    );
    echo json_encode($result, JSON_PRETTY_PRINT) . PHP_EOL;
} catch (Throwable $error) {
    // Do not print credentials, server responses or record data.
    echo json_encode(['schema_reachable' => false,
        'error_type' => get_class($error),
        'http_status' => $error instanceof SupabaseApiException ? $error->statusCode : null,
    ], JSON_PRETTY_PRINT) . PHP_EOL;
    exit(1);
}
