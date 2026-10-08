<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthEdgeTest extends TestCase
{
    use RefreshDatabase;

    public function test_unauthenticated_api_never_500s_without_accept_header(): void
    {
        // No Authorization AND no Accept header (e.g. browser, health probes,
        // broken clients): must be a clean 401, never "Route [login] not defined".
        $res = $this->get('/api/posts', []);
        $res->assertUnauthorized();
        $this->assertStringNotContainsString('login', strtolower($res->getContent()));
    }

    public function test_bad_token_returns_401_json(): void
    {
        $res = $this->getJson('/api/posts', ['Authorization' => 'Bearer wrong']);
        $res->assertUnauthorized()->assertJsonPath('message', 'Unauthenticated.');
    }
}
