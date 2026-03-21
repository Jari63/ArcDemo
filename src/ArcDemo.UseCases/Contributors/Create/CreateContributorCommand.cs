using ArcDemo.Core.ContributorAggregate;

namespace ArcDemo.UseCases.Contributors.Create;

/// <summary>
/// Create a new Contributor.
/// </summary>
/// <param name="Name"></param>
public record CreateContributorCommand(ContributorName Name, string? PhoneNumber) : ICommand<Result<ContributorId>>;
