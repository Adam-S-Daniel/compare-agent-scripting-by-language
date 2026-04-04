// Domain models matching the JSONPlaceholder API schema.
// Uses System.Text.Json naming policy for camelCase JSON property names.

using System.Text.Json.Serialization;

namespace RestApiClient;

/// <summary>Represents a post from /posts endpoint.</summary>
public class Post
{
    [JsonPropertyName("userId")]
    public int UserId { get; set; }

    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("title")]
    public string Title { get; set; } = "";

    [JsonPropertyName("body")]
    public string Body { get; set; } = "";
}

/// <summary>Represents a comment from /comments endpoint.</summary>
public class Comment
{
    [JsonPropertyName("postId")]
    public int PostId { get; set; }

    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("email")]
    public string Email { get; set; } = "";

    [JsonPropertyName("body")]
    public string Body { get; set; } = "";
}

/// <summary>Aggregates a post with all its associated comments.</summary>
public class PostWithComments
{
    [JsonPropertyName("post")]
    public Post Post { get; set; } = new();

    [JsonPropertyName("comments")]
    public List<Comment> Comments { get; set; } = new();
}
