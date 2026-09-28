# Storage

Flint storage is a small helper for saving uploaded files that should be
publicly reachable from the app.

Use this guide when a feature accepts avatars, logos, documents, rich text
images, attachments, or other uploaded files.

Before coding storage in an app, inspect:

- `lib/controllers/` for upload endpoints.
- `lib/models/` for columns that store file URLs or paths.
- `public/` for existing stored public files.
- `docs/routing.md` for request upload helpers.
- `docs/security-and-utilities.md` for upload security checks.

## What Storage Does

`Storage` saves an `UploadedFile` under `public/` and returns a public URL.

Default behavior:

- `Storage.create(file)` stores in `public/uploads`.
- The returned URL starts with `/uploads/`.
- `subdirectory` is relative to `public/`.
- `Storage.delete(url)` deletes a file by public URL.
- `Storage.update(oldUrl, newFile)` deletes the old file and stores the new one.

This is public filesystem storage. It is not a private disk abstraction, object
storage driver, S3 client, or permission system.

## Import

Most apps can import the main framework entrypoint:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Focused imports also work:

```dart
import 'package:flint_dart/storage.dart';
```

## UploadedFile

Multipart uploads become `UploadedFile` objects on the request.

```dart
final upload = await req.file('avatar');

if (upload == null) {
  return res.status(422).json({'message': 'Avatar is required'});
}
```

Useful upload fields:

- `fieldName`
- `filename`
- `contentType`
- `size`
- `extension`
- `uploadedAt`
- `content`

The file content is a stream. Save it once, then use the stored URL or path.

## Create A Public File

```dart
final upload = await req.file('avatar');

if (upload == null) {
  return res.status(422).json({'message': 'Avatar is required'});
}

final avatarUrl = await Storage.create(upload);

return res.json({
  'avatarUrl': avatarUrl,
});
```

The file is saved under:

```text
public/uploads/<uuid>_<filename>
```

The response URL looks like:

```text
/uploads/<uuid>_<filename>
```

## Use A Subdirectory

Use `subdirectory` when files need a clearer public folder.

```dart
final logoUrl = await Storage.create(
  upload,
  subdirectory: 'uploads/schools/logos',
);
```

That saves under:

```text
public/uploads/schools/logos/
```

and returns:

```text
/uploads/schools/logos/<uuid>_<filename>
```

`subdirectory` is relative to `public/`. Do not include `public/`, absolute
paths, or `..` segments.

## Delete A File

Delete with the public URL returned by `Storage.create(...)`.

```dart
await Storage.delete(user.avatarUrl);
```

`Storage.delete('/uploads/a.png')` deletes:

```text
public/uploads/a.png
```

Deleting a missing file does nothing.

## Replace A File

Use `Storage.update(...)` when replacing an old public file with a new upload.

```dart
final newAvatarUrl = await Storage.update(
  user.avatarUrl,
  upload,
  subdirectory: 'uploads/avatars',
);

await user.update({'avatarUrl': newAvatarUrl});
```

`update(...)` deletes the old URL first, then stores the new file.

If old file deletion must be delayed until after the database update succeeds,
write the flow manually:

```dart
final newAvatarUrl = await Storage.create(
  upload,
  subdirectory: 'uploads/avatars',
);

final oldAvatarUrl = user.avatarUrl;
await user.update({'avatarUrl': newAvatarUrl});

if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
  await Storage.delete(oldAvatarUrl);
}
```

## Request Store Helpers

`Request` also has lower-level filesystem helpers.

```dart
final path = await req.storeFile(
  'avatar',
  directory: 'public/uploads/avatars',
);
```

This stores the file and returns a filesystem path, not a public URL.

For multiple uploads:

```dart
final paths = await req.storeFiles(
  'gallery',
  directory: 'public/uploads/gallery',
);
```

Use `Storage` when the app wants a public URL. Use `req.storeFile(...)` or
`req.storeFiles(...)` when a saved path is enough.

## Multiple Files

Use request helpers to inspect multi-file inputs:

```dart
final hasGallery = await req.hasFiles('gallery');
final files = await req.files('gallery');
final allFiles = await req.allFiles();
```

Then store each file:

```dart
final urls = <String>[];

for (final file in await req.files('gallery')) {
  if (file == null) continue;

  final url = await Storage.create(
    file,
    subdirectory: 'uploads/gallery',
  );

  urls.add(url);
}
```

## Validation And Safety

Always validate uploads before storage.

Check:

- the user is authenticated when required
- the user is allowed to upload for this resource
- the field exists
- the file is not too large
- the extension is allowed
- the MIME type is allowed
- the folder is the expected public folder
- the app should keep, delete, or replace any old file

Example:

```dart
final upload = await req.file('avatar');

if (upload == null) {
  return res.status(422).json({'message': 'Avatar is required'});
}

final allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
if (!allowedExtensions.contains(upload.extension?.toLowerCase())) {
  return res.status(422).json({'message': 'Unsupported avatar type'});
}

final maxBytes = 2 * 1024 * 1024;
if ((upload.size ?? 0) > maxBytes) {
  return res.status(422).json({'message': 'Avatar must be 2MB or smaller'});
}
```

Do not rely only on file extensions for sensitive workflows. For user-generated
uploads, also check MIME type and consider scanning or transforming files before
serving them publicly.

## Controller Example

```dart
import 'package:flint_dart/flint_dart.dart';

import '../models/user.dart';

class ProfileAvatarController extends Controller {
  Future<Response> update() async {
    final user = req.requireUser();
    final upload = await req.file('avatar');

    if (upload == null) {
      return res.status(422).json({'message': 'Avatar is required'});
    }

    final oldAvatarUrl = user['avatarUrl']?.toString();
    final avatarUrl = await Storage.create(
      upload,
      subdirectory: 'uploads/avatars',
    );

    await User().update(id: user['id'], data: {'avatarUrl': avatarUrl});

    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      await Storage.delete(oldAvatarUrl);
    }

    return res.json({'avatarUrl': avatarUrl});
  }
}
```

Keep validation and authorization close to the upload controller. Put complex
file workflows in a service or action class in its own file.

## Model Columns

Store the returned URL in a normal string column:

```dart
Column(name: 'avatarUrl', type: ColumnType.string, isNullable: true),
```

Use URLs for public files:

```json
{"avatarUrl": "/uploads/avatars/abc_file.png"}
```

Use filesystem paths only when the file is internal and the app knows how to
serve or process it later.

## Common Mistakes

- Passing `public/uploads` as `subdirectory`. Use `uploads`.
- Treating `Storage` as private storage. Files are saved under `public/`.
- Saving uploads before checking authorization.
- Not checking file size, extension, or MIME type.
- Storing full local filesystem paths in API responses.
- Deleting the old file before a database update when rollback matters.
- Passing arbitrary user input as the storage folder.
- Forgetting that uploaded content streams are consumed when saved.

## Review Checklist

When reviewing file storage:

1. Read `docs/storage.md`.
2. Confirm the upload field is required or optional intentionally.
3. Confirm authorization happens before storage.
4. Confirm file size and file type are checked.
5. Confirm `subdirectory` is app-controlled and relative to `public/`.
6. Confirm public URLs, not local paths, are returned to clients.
7. Confirm old files are deleted only when replacement is successful.
8. Confirm reusable storage workflows live in their own action or service file.
