<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Job extends Model
{
    protected $table = 'job_requests';

    protected $fillable = [
        'user_id', 'craftsman_id', 'accepted_user_id',
        'title', 'description', 'trade', 'city', 'budget', 'status',
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
        return $this->hasMany(Message::class)->orderBy('id');
    }

    public function chatOpen(): bool
    {
        return in_array($this->status, ['accepted', 'completed'], true);
    }

    public function isParticipant(int $userId): bool
    {
        return $userId === (int) $this->user_id || $userId === (int) $this->accepted_user_id;
    }
}
