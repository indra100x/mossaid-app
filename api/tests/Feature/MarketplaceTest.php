<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class MarketplaceTest extends TestCase
{
    use RefreshDatabase;

    /** Authenticate subsequent requests as the given token. */
    private function as(string $token): static
    {
        Auth::forgetGuards(); // Sanctum caches the user per app instance
        return $this->withToken($token);
    }

    private function register(string $role, string $email): array
    {
        $res = $this->postJson('/api/auth/register', [
            'name' => $role.' User',
            'email' => $email,
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => $role,
            'city' => 'Algiers',
        ]);
        $res->assertCreated();

        return [$res->json('user'), $res->json('token')];
    }

    public function test_full_marketplace_flow(): void
    {
        [$craftsman, $craftToken] = $this->register('craftsman', 'craft@test.dz');
        [$client, $clientToken] = $this->register('client', 'client@test.dz');

        // Craftsman publishes a portfolio post
        $post = $this->as($craftToken)->postJson('/api/posts', [
            'title' => 'Peinture intérieure',
            'description' => 'Finitions propres, 10 ans d’expérience.',
            'trade' => 'painter',
            'city' => 'Algiers',
        ])->assertCreated()->json();

        // Client cannot publish posts
        $this->as($clientToken)->postJson('/api/posts', [
            'title' => 'x', 'description' => 'y', 'trade' => 'painter',
        ])->assertForbidden();

        // Search posts
        $this->as($clientToken)->getJson('/api/posts?trade=painter')
            ->assertOk()->assertJsonPath('data.0.id', $post['id']);

        // Like toggle + comment
        $this->as($clientToken)->postJson("/api/posts/{$post['id']}/like")
            ->assertOk()->assertJsonPath('liked', true);
        $this->as($clientToken)->postJson("/api/posts/{$post['id']}/comments", [
            'body' => 'Super travail !',
        ])->assertCreated();

        // Client posts a job request
        $job = $this->as($clientToken)->postJson('/api/jobs', [
            'title' => 'Repeindre salon',
            'description' => '40m2, peinture blanche.',
            'trade' => 'painter',
            'city' => 'Algiers',
            'budget' => 30000,
        ])->assertCreated()->json();

        // Craftsman cannot post jobs
        $this->as($craftToken)->postJson('/api/jobs', [
            'title' => 'x', 'description' => 'y', 'trade' => 'painter',
        ])->assertForbidden();

        // Chat blocked before accept
        $this->as($clientToken)->getJson("/api/jobs/{$job['id']}/messages")
            ->assertForbidden();

        // Craftsman accepts → chat opens for both
        $this->as($craftToken)->postJson("/api/jobs/{$job['id']}/accept")
            ->assertOk()->assertJsonPath('status', 'accepted');

        $msg = $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/messages", [
            'body' => 'Salam, quand pouvez-vous passer ?',
        ])->assertCreated()->json();

        $this->as($craftToken)->getJson("/api/jobs/{$job['id']}/messages?after=2000-01-01T00:00:00Z")
            ->assertOk()->assertJsonPath('data.0.id', $msg['id']);
        // Newer-than cursor excludes what we already have.
        $this->as($craftToken)->getJson(
            "/api/jobs/{$job['id']}/messages?after={$msg['created_at']}"
        )->assertOk()->assertJsonCount(0, 'data');

        $this->as($craftToken)->postJson("/api/jobs/{$job['id']}/messages", [
            'body' => 'Demain inchallah.',
        ])->assertCreated();

        // Client completes
        $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/complete")
            ->assertOk()->assertJsonPath('status', 'completed');
    }
}
