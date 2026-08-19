class FaceBox {
  const FaceBox({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final int top;
  final int right;
  final int bottom;
  final int left;

  factory FaceBox.fromJson(Map<String, dynamic> json) => FaceBox(
        top: json['top'] as int,
        right: json['right'] as int,
        bottom: json['bottom'] as int,
        left: json['left'] as int,
      );
}

class RecognizedFace {
  const RecognizedFace({
    required this.index,
    required this.matched,
    required this.box,
    this.faceId,
    this.name,
    this.distance,
    this.similarity,
  });

  final int index;
  final bool matched;
  final FaceBox box;
  final String? faceId;
  final String? name;
  final double? distance;
  final double? similarity;

  factory RecognizedFace.fromJson(Map<String, dynamic> json) => RecognizedFace(
        index: json['index'] as int,
        matched: json['matched'] as bool,
        box: FaceBox.fromJson(json['box'] as Map<String, dynamic>),
        faceId: json['faceId'] as String?,
        name: json['name'] as String?,
        distance: (json['distance'] as num?)?.toDouble(),
        similarity: (json['similarity'] as num?)?.toDouble(),
      );

  RecognizedFace tagged(String tag, String id) => RecognizedFace(
        index: index,
        matched: true,
        box: box,
        faceId: id,
        name: tag,
        distance: 0,
        similarity: 1,
      );
}

class RecognitionResponse {
  const RecognitionResponse({
    required this.faces,
    required this.width,
    required this.height,
  });

  final List<RecognizedFace> faces;
  final int width;
  final int height;

  factory RecognitionResponse.fromJson(Map<String, dynamic> json) {
    final facesJson = (json['faces'] as List<dynamic>? ?? const []);
    return RecognitionResponse(
      faces: facesJson
          .map((e) => RecognizedFace.fromJson(e as Map<String, dynamic>))
          .toList(),
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}

class SavedFace {
  const SavedFace({
    required this.id,
    required this.name,
    this.imagePath,
  });

  final String id;
  final String name;
  final String? imagePath;

  factory SavedFace.fromJson(Map<String, dynamic> json) => SavedFace(
        id: json['id'] as String,
        name: json['name'] as String,
        imagePath: json['imagePath'] as String?,
      );
}
