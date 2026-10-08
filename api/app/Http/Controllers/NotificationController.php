<?php

namespace App\Http\Controllers;

use App\Models\AppNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = AppNotification::where('user_id', $request->user()->id)
            ->latest();
        $res = $q->paginate(30)->toArray();
        $res['unread_count'] = AppNotification::where('user_id', $request->user()->id)
            ->whereNull('read_at')->count();

        return response()->json($res);
    }

    public function read(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['nullable', 'array'],
            'ids.*' => ['integer'],
        ]);

        $q = AppNotification::where('user_id', $request->user()->id)
            ->whereNull('read_at');
        if (! empty($data['ids'])) {
            $q->whereIn('id', $data['ids']);
        }
        $count = $q->update(['read_at' => now()]);

        return response()->json(['marked_read' => $count]);
    }
}
