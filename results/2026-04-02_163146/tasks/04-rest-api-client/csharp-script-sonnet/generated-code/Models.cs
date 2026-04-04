// TDD GREEN: Models created to make ModelTests pass
// Records are immutable by default and ideal for API response objects.
// JsonPropertyName attributes map PascalCase C# properties to
// camelCase JSON keys returned by JSONPlaceholder.

using System.Text.Json.Serialization;

namespace RestApiClient;

/// <summary>A post from the JSONPlaceholder API (/posts).</summary>
public record Post(
    [property: JsonPropertyName("id")]     int    Id,
    [property: JsonPropertyName("userId")] int    UserId,
    [property: JsonPropertyName("title")]  string Title,
    [property: JsonPropertyName("body")]   string Body
);

/// <summary>A comment from the JSONPlaceholder API (/posts/{id}/comments).</summary>
public record Comment(
    [property: JsonPropertyName("id")]     int    Id,
    [property: JsonPropertyName("postId")] int    PostId,
    [property: JsonPropertyName("name")]   string Name,
    [property: JsonPropertyName("email")]  string Email,
    [property: JsonPropertyName("body")]   string Body
);

/// <summary>A post combined with all of its comments (composite result type).</summary>
public record PostWithComments(Post Post, IReadOnlyList<Comment> Comments);
