<?php

namespace App\Http\Controllers;

use App\Models\AppNotification;
use App\Models\Job;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class JobController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = Job::with(['client:id,name,city', 'acceptedCraftsman:id,name,trade'])
            ->orderByDesc('id');

        foreach (['trade', 'city', 'status'] as $f) {
            if ($v = $request->query($f)) {
                $q->where($f, $v);
            }
        }
        if ($search = $request->query('q')) {
            $q->where(function ($w) use ($search) {
                $w->where('title', 'ilike', "%{$search}%")
                    ->orWhere('description', 'ilike', "%{$search}%");
            });
        }
        if ($request->query('mine') && $request->user()) {
            $uid = $request->user()->id;
            $q->where(function ($w) use ($uid) {
                $w->where('user_id', $uid)->orWhere('accepted_user_id', $uid);
            });
        }

        return response()->json($q->paginate(20));
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless(! $user->isCraftsman(), 403, 'Only clients post job requests.');

        $data = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'description' => ['required', 'string', 'max:5000'],
            'trade' => ['required', 'string', 'max:60'],
            'city' => ['nullable', 'string', 'max:80'],
            'budget' => ['nullable', 'integer', 'min:0'],
            'cover_photo' => ['nullable', 'url', 'max:500'],
            'craftsman_id' => ['nullable', 'exists:users,id'],
        ]);

        $job = $user->jobs()->create($data);

        return response()->json($job, 201);
    }

    public function show(Job $job): JsonResponse
    {
        $job->load(['client:id,name,city', 'craftsman:id,name,trade', 'acceptedCraftsman:id,name,trade']);

        return response()->json($job);
    }

    public function accept(Request $request, Job $job): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->isCraftsman(), 403, 'Only craftsmen can accept jobs.');
        abort_unless($job->status === 'open', 409, 'Job is not open.');

        $job->update(['status' => 'accepted', 'accepted_user_id' => $user->id]);

        AppNotification::notify(
            $job->user_id, 'job.accepted',
            "{$user->name} accepted your job",
            "“{$job->title}” — chat is now open.",
            ['job_id' => $job->id, 'actor_name' => $user->name],
        );

        return response()->json($job->fresh());
    }

    public function complete(Request $request, Job $job): JsonResponse
    {
        abort_unless($job->user_id === $request->user()->id, 403, 'Only the client closes the job.');
        abort_unless($job->status === 'accepted', 409, 'Only accepted jobs can be completed.');

        $job->update(['status' => 'completed']);

        if ($job->accepted_user_id) {
            AppNotification::notify(
                $job->accepted_user_id, 'job.completed',
                'Job marked completed',
                "“{$job->title}” — the client closed the job.",
                ['job_id' => $job->id, 'actor_name' => $job->client->name],
            );
        }

        return response()->json($job->fresh());
    }

    public function cancel(Request $request, Job $job): JsonResponse
    {
        $user = $request->user();
        $isOwner = $job->user_id === $user->id;
        $isAccepter = $job->accepted_user_id === $user->id;
        abort_unless($isOwner || $isAccepter, 403);
        abort_unless(in_array($job->status, ['open', 'accepted'], true), 409);

        $job->update(['status' => 'cancelled']);

        return response()->json($job->fresh());
    }
}
