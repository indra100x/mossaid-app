<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Job extends Model
{
    use HasUuids;

    protected $table = 'job_requests';

    protected $fillable = [
        'user_id', 'craftsman_id', 'accepted_user_id',
        'title', 'description', 'trade', 'city', 'budget', 'cover_photo', 'status',
    ];

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function craftsman(): BelongsTo
    {
        return $this->belongsTo(User::class, 'craftsman_id');
    }

    public function acceptedCraftsman(): BelongsTo
    {
        return $this->belongsTo(User::class, 'accepted_user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class)->orderBy('created_at');
    }

    public function chatOpen(): bool
    {
        return in_array($this->status, ['accepted', 'completed'], true);
    }

    public function isParticipant(string $userId): bool
    {
        return $userId === (string) $this->user_id || $userId === (string) $this->accepted_user_id;
    }
}
