using ArcDemo.Core.ContributorAggregate;

namespace ArcDemo.UseCases.Contributors;
public record ContributorDto(ContributorId Id, ContributorName Name, PhoneNumber PhoneNumber);
