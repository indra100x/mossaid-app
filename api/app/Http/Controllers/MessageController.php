<?php

namespace App\Http\Controllers;

use App\Models\AppNotification;
use App\Models\Job;
use App\Models\Message;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    private function ensureChatAllowed(Job $job, string $userId): void
    {
        abort_unless($job->chatOpen(), 403, 'Chat opens only after a craftsman accepts the job.');
        abort_unless($job->isParticipant($userId), 403, 'Not a participant of this job.');
    }

    public function index(Request $request, Job $job): JsonResponse
    {
        $this->ensureChatAllowed($job, (string) $request->user()->id);

        $q = $job->messages()->with('sender:id,name');
        if ($after = $request->query('after')) {
            try {
                $q->where('created_at', '>', new \DateTime($after));
            } catch (\Exception) {
                abort(422, 'Invalid after cursor.');
            }
        }

        return response()->json($q->orderBy('created_at')->paginate(50));
    }

    public function store(Request $request, Job $job): JsonResponse
    {
        $this->ensureChatAllowed($job, (string) $request->user()->id);

        $data = $request->validate(['body' => ['required', 'string', 'max:2000']]);

        $msg = Message::create([
            'job_id' => $job->id,
            'sender_id' => $request->user()->id,
            'body' => $data['body'],
        ]);
        $msg->load('sender:id,name');

        $mine = (string) $request->user()->id;
        $otherId = $mine === (string) $job->user_id
            ? (string) $job->accepted_user_id
            : (string) $job->user_id;
        if ($otherId) {
            AppNotification::notify(
                $otherId, 'message.received',
                "New message from {$request->user()->name}",
                mb_substr($data['body'], 0, 120),
                ['job_id' => $job->id, 'actor_name' => $request->user()->name],
            );
        }

        return response()->json($msg, 201);
    }
}
