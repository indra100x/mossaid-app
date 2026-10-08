<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MarketplacePlusTest extends TestCase
{
    use RefreshDatabase;

    private function register(string $role, string $email): array
    {
        $res = $this->postJson('/api/auth/register', [
            'name' => $role.' User',
            'email' => $email,
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => $role,
        ]);
        $res->assertCreated();

        return [$res->json('user'), $res->json('token')];
    }

    private function as(string $token): static
    {
        \Illuminate\Support\Facades\Auth::forgetGuards();

        return $this->withToken($token);
    }

    public function test_meta_is_public(): void
    {
        $this->getJson('/api/meta')->assertOk()
            ->assertJsonStructure(['trades', 'cities']);
    }

    public function test_upload_review_notify_profile_reset_flow(): void
    {
        Storage::fake('public');
        [$craft, $craftToken] = $this->register('craftsman', 'c2@test.dz');
        [, $clientToken] = $this->register('client', 'l2@test.dz');

        // Upload a portfolio photo.
        $this->as($craftToken)->postJson('/api/uploads', [])
            ->assertStatus(422); // photo required
        $up = $this->as($craftToken)->post(
            '/api/uploads',
            ['photo' => UploadedFile::fake()->image('work.jpg')],
        );
        $up->assertCreated();
        $photoUrl = json_decode($up->getContent(), true)['url'];
        $this->assertStringContainsString('/storage/', $photoUrl);

        // Post with photo, then a full job cycle.
        $post = $this->as($craftToken)->postJson('/api/posts', [
            'title' => 'Tiling', 'description' => 'Bathroom tiling pro.',
            'trade' => 'tiler', 'photos' => [$photoUrl],
        ])->assertCreated()->json();

        $job = $this->as($clientToken)->postJson('/api/jobs', [
            'title' => 'Tile kitchen', 'description' => '20m2 floor.',
            'trade' => 'tiler',
        ])->assertCreated()->json();

        // Review before completion is rejected.
        $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/reviews", [
            'rating' => 5,
        ])->assertStatus(409);

        $this->as($craftToken)->postJson("/api/jobs/{$job['id']}/accept")->assertOk();
        // Accept notified the client.
        $notifs = $this->as($clientToken)->getJson('/api/notifications')->assertOk()->json();
        $this->assertEquals(1, $notifs['unread_count']);
        $this->assertEquals('job.accepted', $notifs['data'][0]['type']);

        $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/complete")->assertOk();

        // Review + rating aggregation.
        $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/reviews", [
            'rating' => 5, 'comment' => 'Excellent!',
        ])->assertCreated();
        // Duplicate review rejected.
        $this->as($clientToken)->postJson("/api/jobs/{$job['id']}/reviews", [
            'rating' => 4,
        ])->assertStatus(409);

        $pub = $this->getJson("/api/craftsmen/{$craft['id']}/reviews")->assertOk()->json();
        $this->assertEquals(5, $pub['craftsman']['rating_avg']);
        $this->assertEquals(1, $pub['craftsman']['rating_count']);

        // Mark notifications read.
        $this->as($clientToken)->postJson('/api/notifications/read', [])
            ->assertOk()->assertJsonPath('marked_read', 1);

        // Profile edit.
        $me = $this->as($clientToken)->patchJson('/api/auth/profile', [
            'city' => 'Oran', 'bio' => 'Hello',
        ])->assertOk()->json();
        $this->assertEquals('Oran', $me['city']);

        // Password reset cycle.
        $forgot = $this->postJson('/api/auth/forgot', ['email' => 'l2@test.dz'])
            ->assertOk()->json();
        $this->assertArrayHasKey('code', $forgot);
        $this->postJson('/api/auth/reset', [
            'email' => 'l2@test.dz', 'code' => $forgot['code'],
            'password' => 'newpass123', 'password_confirmation' => 'newpass123',
        ])->assertOk();
        $this->postJson('/api/auth/login', [
            'email' => 'l2@test.dz', 'password' => 'newpass123',
        ])->assertOk();
    }
}
