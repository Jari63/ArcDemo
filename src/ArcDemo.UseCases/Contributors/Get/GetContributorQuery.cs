using ArcDemo.Core.ContributorAggregate;

namespace ArcDemo.UseCases.Contributors.Get;

public record GetContributorQuery(ContributorId ContributorId) : IQuery<Result<ContributorDto>>;
