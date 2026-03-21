using ArcDemo.Core.ContributorAggregate;
using Vogen;

namespace ArcDemo.Infrastructure.Data.Config;

[EfCoreConverter<ContributorId>]
[EfCoreConverter<ContributorName>]
internal partial class VogenEfCoreConverters;
