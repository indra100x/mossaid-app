<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppNotification extends Model
{
    protected $table = 'notifications';

    protected $fillable = [
        'user_id', 'type', 'title', 'body', 'data', 'read_at',
    ];

    protected function casts(): array
    {
        return ['data' => 'array', 'read_at' => 'datetime'];
    }

    public static function notify(
        int $userId,
        string $type,
        string $title,
        ?string $body = null,
        ?array $data = null,
    ): self {
        return self::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);
    }
}
