<?php

namespace App\Http\Controllers;

use App\Models\Job;
use App\Models\Message;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    private function ensureChatAllowed(Job $job, int $userId): void
    {
        abort_unless($job->chatOpen(), 403, 'Chat opens only after a craftsman accepts the job.');
        abort_unless($job->isParticipant($userId), 403, 'Not a participant of this job.');
    }

    public function index(Request $request, Job $job): JsonResponse
    {
        $this->ensureChatAllowed($job, $request->user()->id);

        $q = $job->messages()->with('sender:id,name');
        if ($after = $request->query('after_id')) {
            $q->where('id', '>', (int) $after);
        }

        return response()->json($q->orderBy('id')->paginate(50));
    }

    public function store(Request $request, Job $job): JsonResponse
    {
        $this->ensureChatAllowed($job, $request->user()->id);

        $data = $request->validate(['body' => ['required', 'string', 'max:2000']]);

        $msg = Message::create([
            'job_id' => $job->id,
            'sender_id' => $request->user()->id,
            'body' => $data['body'],
        ]);
        $msg->load('sender:id,name');

        return response()->json($msg, 201);
    }
}
