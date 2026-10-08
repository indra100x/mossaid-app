<?php

namespace App\Http\Controllers;

use App\Models\Comment;
use App\Models\Like;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PostController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = Post::with('user:id,name,trade,city,rating_avg,rating_count')->withCount(['likes', 'comments'])->orderByDesc('created_at');

        if ($trade = $request->query('trade')) {
            $q->where('trade', $trade);
        }
        if ($city = $request->query('city')) {
            $q->where('city', $city);
        }
        if ($search = $request->query('q')) {
            $q->where(function ($w) use ($search) {
                $w->where('title', 'ilike', "%{$search}%")
                    ->orWhere('description', 'ilike', "%{$search}%");
            });
        }
        if ($request->boolean('mine')) {
            $q->where('user_id', $request->user()->id);
        }

        return response()->json($q->paginate(20));
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->isCraftsman(), 403, 'Only craftsmen can publish posts.');

        $data = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'description' => ['required', 'string', 'max:5000'],
            'trade' => ['required', 'string', 'max:60'],
            'city' => ['nullable', 'string', 'max:80'],
            'price_hint' => ['nullable', 'integer', 'min:0'],
            'photos' => ['nullable', 'array', 'max:6'],
            'photos.*' => ['url', 'max:500'],
        ]);

        $post = $user->posts()->create($data);
        $post->load('user:id,name,trade,city');

        return response()->json($post, 201);
    }

    public function show(Post $post): JsonResponse
    {
        $post->load(['user:id,name,trade,city,bio', 'comments.user:id,name']);
        $post->loadCount(['likes', 'comments']);

        return response()->json($post);
    }

    public function update(Request $request, Post $post): JsonResponse
    {
        abort_unless($post->user_id === $request->user()->id, 403);

        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:150'],
            'description' => ['sometimes', 'string', 'max:5000'],
            'trade' => ['sometimes', 'string', 'max:60'],
            'city' => ['nullable', 'string', 'max:80'],
            'price_hint' => ['nullable', 'integer', 'min:0'],
            'photos' => ['nullable', 'array', 'max:6'],
            'photos.*' => ['url', 'max:500'],
        ]);

        $post->update($data);

        return response()->json($post);
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        abort_unless($post->user_id === $request->user()->id, 403);
        $post->delete();

        return response()->json(['ok' => true]);
    }

    public function toggleLike(Request $request, Post $post): JsonResponse
    {
        $existing = Like::where('user_id', $request->user()->id)
            ->where('post_id', $post->id)->first();

        if ($existing) {
            $existing->delete();
            $post->decrement('likes_count');
            $liked = false;
        } else {
            Like::create(['user_id' => $request->user()->id, 'post_id' => $post->id]);
            $post->increment('likes_count');
            $liked = true;
        }

        return response()->json(['liked' => $liked, 'likes_count' => $post->fresh()->likes_count]);
    }

    public function comments(Post $post): JsonResponse
    {
        return response()->json(
            $post->comments()->with('user:id,name')->paginate(30)
        );
    }

    public function addComment(Request $request, Post $post): JsonResponse
    {
        $data = $request->validate(['body' => ['required', 'string', 'max:1000']]);

        $comment = Comment::create([
            'user_id' => $request->user()->id,
            'post_id' => $post->id,
            'body' => $data['body'],
        ]);
        $comment->load('user:id,name');

        return response()->json($comment, 201);
    }
}
