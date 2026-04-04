// TDD Cycle 1 - RED: Tests for Post and Comment model serialization.
// These tests verify that our domain models correctly serialize/deserialize
// to/from JSON, matching the JSONPlaceholder API schema.

using System.Text.Json;
using RestApiClient;

namespace RestApiClient.Tests;

public class ModelTests
{
    // RED: Verify Post model deserializes from JSONPlaceholder-style JSON
    [Fact]
    public void Post_DeserializesFromJson()
    {
        var json = """
        {
            "userId": 1,
            "id": 42,
            "title": "Test Post Title",
            "body": "This is the body of the test post."
        }
        """;

        var post = JsonSerializer.Deserialize<Post>(json);

        Assert.NotNull(post);
        Assert.Equal(1, post.UserId);
        Assert.Equal(42, post.Id);
        Assert.Equal("Test Post Title", post.Title);
        Assert.Equal("This is the body of the test post.", post.Body);
    }

    // RED: Verify Comment model deserializes from JSONPlaceholder-style JSON
    [Fact]
    public void Comment_DeserializesFromJson()
    {
        var json = """
        {
            "postId": 42,
            "id": 7,
            "name": "Comment Name",
            "email": "test@example.com",
            "body": "This is a comment body."
        }
        """;

        var comment = JsonSerializer.Deserialize<Comment>(json);

        Assert.NotNull(comment);
        Assert.Equal(42, comment.PostId);
        Assert.Equal(7, comment.Id);
        Assert.Equal("Comment Name", comment.Name);
        Assert.Equal("test@example.com", comment.Email);
        Assert.Equal("This is a comment body.", comment.Body);
    }

    // RED: Verify Post model round-trips through serialization
    [Fact]
    public void Post_SerializesAndDeserializesRoundTrip()
    {
        var original = new Post
        {
            UserId = 5,
            Id = 100,
            Title = "Round Trip",
            Body = "Testing round trip"
        };

        var json = JsonSerializer.Serialize(original);
        var deserialized = JsonSerializer.Deserialize<Post>(json);

        Assert.NotNull(deserialized);
        Assert.Equal(original.UserId, deserialized.UserId);
        Assert.Equal(original.Id, deserialized.Id);
        Assert.Equal(original.Title, deserialized.Title);
        Assert.Equal(original.Body, deserialized.Body);
    }

    // RED: Verify PostWithComments holds a post and its associated comments
    [Fact]
    public void PostWithComments_HoldsPostAndComments()
    {
        var post = new Post { UserId = 1, Id = 1, Title = "T", Body = "B" };
        var comments = new List<Comment>
        {
            new() { PostId = 1, Id = 1, Name = "N", Email = "e@e.com", Body = "C" }
        };

        var pwc = new PostWithComments { Post = post, Comments = comments };

        Assert.Equal(1, pwc.Post.Id);
        Assert.Single(pwc.Comments);
        Assert.Equal(1, pwc.Comments[0].PostId);
    }
}
