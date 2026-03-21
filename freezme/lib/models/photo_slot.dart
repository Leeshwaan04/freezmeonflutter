enum PhotoSlotStatus { empty, uploading, uploaded, error }

class PhotoSlot {
  const PhotoSlot({
    required this.status,
    this.imageUrl,
    this.localPath,
  });

  final PhotoSlotStatus status;
  final String? imageUrl;
  final String? localPath;
}
