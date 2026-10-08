<?php

namespace App\Http\Controllers;

use App\Models\AppNotification;
use App\Models\Job;
use App\Models\Review;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function store(Request $request, Job $job): JsonResponse
    {
        abort_unless($job->user_id === $request->user()->id, 403, 'Only the client reviews.');
        abort_unless($job->status === 'completed', 409, 'Only completed jobs can be reviewed.');
        abort_if($job->accepted_user_id === null, 409, 'No craftsman to review.');
        abort_if(Review::where('job_id', $job->id)->exists(), 409, 'Job already reviewed.');

        $data = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        $review = Review::create([
            'job_id' => $job->id,
            'reviewer_id' => $request->user()->id,
            'craftsman_id' => $job->accepted_user_id,
            'rating' => $data['rating'],
            'comment' => $data['comment'] ?? null,
        ]);

        $craftsman = User::findOrFail($job->accepted_user_id);
        $count = $craftsman->rating_count + 1;
        $craftsman->update([
            'rating_count' => $count,
            'rating_avg' => round(
                ($craftsman->rating_avg * $craftsman->rating_count + $data['rating']) / $count, 2
            ),
        ]);

        AppNotification::notify(
            $craftsman->id, 'review.received',
            "New {$data['rating']}★ review",
            $request->user()->name.' reviewed your work.',
            ['job_id' => $job->id, 'rating' => $data['rating']],
        );

        return response()->json($review, 201);
    }

    public function forCraftsman(Request $request, User $user): JsonResponse
    {
        abort_unless($user->isCraftsman(), 404);
        $reviews = Review::where('craftsman_id', $user->id)
            ->with('reviewer:id,name')
            ->latest()
            ->paginate(20);

        return response()->json([
            'craftsman' => $user->only(['id', 'name', 'trade', 'city', 'bio', 'rating_avg', 'rating_count']),
            'reviews' => $reviews,
        ]);
    }
}
