using ArcDemo.Core.ContributorAggregate;

namespace ArcDemo.UseCases.Contributors.Update;

public record UpdateContributorCommand(ContributorId ContributorId, ContributorName NewName) : ICommand<Result<ContributorDto>>;
