<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Review extends Model
{
    protected $fillable = [
        'job_id', 'reviewer_id', 'craftsman_id', 'rating', 'comment',
    ];

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }

    public function craftsman(): BelongsTo
    {
        return $this->belongsTo(User::class, 'craftsman_id');
    }
}
