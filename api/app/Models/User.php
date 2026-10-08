<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'password',
        'role', 'phone', 'trade', 'city', 'bio',
        'rating_avg', 'rating_count',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function isCraftsman(): bool
    {
        return $this->role === 'craftsman';
    }

    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    public function jobs(): HasMany
    {
        return $this->hasMany(Job::class);
    }
}
