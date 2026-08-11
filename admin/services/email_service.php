<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/env.php';

final class EmailService
{
    private string $from;
    private string $appName;

    public function __construct()
    {
        $this->from = Env::required('MAIL_FROM');
        $this->appName = Env::get('APP_NAME', 'MyFind') ?? 'MyFind';
        if (filter_var($this->from, FILTER_VALIDATE_EMAIL) === false) {
            throw new RuntimeException('MAIL_FROM must be a valid email address.');
        }
    }

    public function sendApproval(string $to, string $fullName, string $actionLink): bool
    {
        $safeName = htmlspecialchars($fullName, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        $safeLink = htmlspecialchars($actionLink, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        $body = <<<HTML
            <p>Hello {$safeName},</p>
            <p>Your registration application has been approved.</p>
            <p>Your account is now ready. Use the secure link below to set your password, then log in through the mobile application.</p>
            <p><a href="{$safeLink}">Set your password securely</a></p>
            <p>If you did not submit this application, ignore this email and contact support.</p>
            HTML;

        return $this->send($to, 'Registration Application Approved', $body);
    }

    public function sendRejection(
        string $to,
        string $fullName,
        ?string $reason
    ): bool {
        $safeName = htmlspecialchars($fullName, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        $reasonBlock = '';
        if ($reason !== null && trim($reason) !== '') {
            $safeReason = nl2br(htmlspecialchars(
                trim($reason),
                ENT_QUOTES | ENT_SUBSTITUTE,
                'UTF-8'
            ));
            $reasonBlock = "<p><strong>Reason:</strong><br>{$safeReason}</p>";
        }
        $body = <<<HTML
            <p>Hello {$safeName},</p>
            <p>Your registration application has been reviewed and was not approved.</p>
            {$reasonBlock}
            <p>You may contact support if you need clarification.</p>
            HTML;

        return $this->send($to, 'Registration Application Rejected', $body);
    }

    private function send(string $to, string $subject, string $html): bool
    {
        if (filter_var($to, FILTER_VALIDATE_EMAIL) === false) {
            return false;
        }
        $headers = [
            'MIME-Version: 1.0',
            'Content-Type: text/html; charset=UTF-8',
            'From: ' . $this->appName . ' <' . $this->from . '>',
            'Reply-To: ' . $this->from,
            'X-Mailer: PHP/' . PHP_VERSION,
        ];
        return @mail($to, $subject, $html, implode("\r\n", $headers));
    }
}
