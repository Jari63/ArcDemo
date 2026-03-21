using ArcDemo.Core.ContributorAggregate;

namespace ArcDemo.UseCases.Contributors.Delete;

public record DeleteContributorCommand(ContributorId ContributorId) : ICommand<Result>;
