# Blog Relation Test Example Plan

## Purpose

Create a small Flint example app that proves relation loading works in a real project, not only in isolated framework tests.

The example should behave like a simple public blog:

- Anyone can register.
- Registered users can create blog posts.
- Registered users can comment on posts.
- Public visitors can read posts and comments.
- Admin or post owner can moderate content later.

The main goal is to exercise Flint model relations heavily and clearly.

## Why This Example Matters

EuCloudHost exposed a practical relation issue where a page expected related customer data but received empty relation data. A blog app is a good framework-level sample because it naturally uses the same relation patterns:

- `Post belongsTo User`
- `Comment belongsTo User`
- `Comment belongsTo Post`
- `User hasMany Post`
- `User hasMany Comment`
- `Post hasMany Comment`
- Optional later: `Post belongsToMany Tag`

This gives Flint a repeatable example for `withRelation`, `withRelations`, selected relation columns, relation counts, and nested presentation.

## Target User Flow

1. A visitor opens the blog index.
2. A visitor registers with name, email, and password.
3. The registered user creates a blog post.
4. Another registered user comments on that post.
5. The blog index shows posts with author names and comment counts.
6. The post detail page shows the post author, comments, and each comment author.
7. The API can return the same data as JSON using Flint relations.

## Models

### User

Table: `users`

Fields:

- `id`
- `name`
- `email`
- `password`
- `role`
- `created_at`
- `updated_at`

Relations:

- `posts`: hasMany `Post`, foreign key `userId`
- `comments`: hasMany `Comment`, foreign key `userId`

### Post

Table: `posts`

Fields:

- `id`
- `userId`
- `title`
- `slug`
- `excerpt`
- `body`
- `status`
- `publishedAt`
- `created_at`
- `updated_at`

Relations:

- `author`: belongsTo `User`, foreign key `userId`
- `comments`: hasMany `Comment`, foreign key `postId`

### Comment

Table: `comments`

Fields:

- `id`
- `postId`
- `userId`
- `body`
- `status`
- `created_at`
- `updated_at`

Relations:

- `post`: belongsTo `Post`, foreign key `postId`
- `author`: belongsTo `User`, foreign key `userId`

### Tag Later

Table: `tags`

Fields:

- `id`
- `name`
- `slug`

Pivot table: `post_tags`

Fields:

- `id`
- `postId`
- `tagId`

Relations:

- `Post tags`: belongsToMany `Tag`
- `Tag posts`: belongsToMany `Post`

## Required Relation Test Cases

### 1. BelongsTo With Selected Columns

Use:

```dart
final posts = await Post()
    .withRelation('author', columns: ['name', 'email'])
    .get();
```

Expected:

- Each post can call `post.getRelation<User>('author')`.
- The related user includes `id` even if the caller did not request it.
- The related user includes `name` and `email`.

This protects the EuCloudHost-style customer relation bug.

### 2. HasMany With Selected Columns

Use:

```dart
final posts = await Post()
    .withRelation('comments', columns: ['postId', 'userId', 'body'])
    .get();
```

Expected:

- Each post can call `post.getRelation<List>('comments')`.
- Comments are grouped under the correct post.
- The relation loader includes `postId` if needed for grouping.

### 3. Multiple Relations

Use:

```dart
final posts = await Post().withRelations(['author', 'comments']).get();
```

Expected:

- `author` is a `User`.
- `comments` is a list.
- Empty comments return an empty list, not null.

### 4. Comment Author Relation

Use:

```dart
final comments = await Comment()
    .withRelation('author', columns: ['name'])
    .withRelation('post', columns: ['title', 'slug'])
    .get();
```

Expected:

- Comment author is hydrated.
- Comment post is hydrated.
- Selected columns still keep relation keys available internally.

### 5. Relation Counts

Use:

```dart
final counts = await user.relationCounts('posts', {
  'published': (query) => query.where('status', '=', 'published'),
  'draft': (query) => query.where('status', '=', 'draft'),
});
```

Expected:

- Counts are returned without manually writing SQL.
- Relation metadata provides the foreign key.

## Routes

### Public Web Routes

- `GET /blog`
- `GET /blog/:slug`
- `GET /register`
- `POST /register`
- `GET /login`
- `POST /login`

### Authenticated Routes

- `GET /dashboard/posts`
- `GET /dashboard/posts/create`
- `POST /dashboard/posts`
- `GET /dashboard/posts/:id/edit`
- `PUT /dashboard/posts/:id`
- `DELETE /dashboard/posts/:id`
- `POST /blog/:slug/comments`

### JSON API Routes

- `GET /api/blog/posts`
- `GET /api/blog/posts/:slug`
- `POST /api/blog/posts`
- `POST /api/blog/posts/:id/comments`
- `GET /api/blog/users/:id`

## Controllers

### AuthController

Responsibilities:

- Register user.
- Login user.
- Logout user.
- Keep password concealed in serialized output.

### BlogController

Responsibilities:

- Public post index.
- Public post detail.
- Return posts with authors and comment counts.
- Return post detail with comments and comment authors.

### PostController

Responsibilities:

- Create post for current user.
- Edit only current user's post unless admin.
- Delete only current user's post unless admin.

### CommentController

Responsibilities:

- Add comment to a published post.
- Load comment author and post relations.
- Later moderation: hide or approve comments.

## Seeder Data

Create seeders for:

- Two users:
  - Ada Lovelace
  - Grace Hopper
- Three posts:
  - Two published
  - One draft
- Four comments spread across the published posts.

Seeder should prove relation data can be read immediately after seeding.

## UI Screens

### Blog Index

Show:

- Post title
- Author name
- Excerpt
- Published date
- Comment count

### Blog Detail

Show:

- Post title
- Author name and email if allowed
- Full body
- Comments
- Comment author names
- Comment form for logged-in users

### User Dashboard

Show:

- My posts
- Draft/published status
- Comment count
- Create/edit/delete actions

## Acceptance Checklist

- `dart analyze lib test` passes for the example and framework.
- `dart test test/model_test.dart` includes relation cases.
- The example app has real `User`, `Post`, and `Comment` models.
- `withRelation('author', columns: ['name', 'email'])` returns a typed `User`.
- `withRelation('comments')` returns a typed list or empty list.
- `relationCounts` works for a user's published and draft posts.
- Public blog pages do not expose passwords or hidden fields.
- The example README links to this plan.

## Implementation Order

1. Create `User`, `Post`, and `Comment` models.
2. Register their tables in `table_registry.dart`.
3. Add seeders for users, posts, and comments.
4. Add relation-focused tests first.
5. Add JSON API routes.
6. Add public blog pages.
7. Add authenticated post/comment actions.
8. Add README usage steps.

## Notes

This should stay as a Flint example, not a product-specific EuCloudHost feature. The code should be small, readable, and useful for future framework debugging.
