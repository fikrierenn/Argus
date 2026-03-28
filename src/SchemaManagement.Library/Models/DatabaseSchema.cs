namespace SchemaManagement.Library.Models;

public class DatabaseSchema
{
    public string Name { get; set; } = string.Empty;
    public Dictionary<string, EntityInfo> Entities { get; set; } = new();
}

public class EntityInfo
{
    public string TableName { get; set; } = string.Empty;
    public Dictionary<string, PropertyInfo> Properties { get; set; } = new();
    public List<RelationshipInfo> Relationships { get; set; } = new();
    public bool HasCompositePrimaryKey { get; set; }
    public bool IsAuditable { get; set; }
    public bool IsVersioned { get; set; }
    public bool IsSoftDeletable { get; set; }
}

public class PropertyInfo
{
    public string ColumnName { get; set; } = string.Empty;
    public string PropertyName { get; set; } = string.Empty;
    public bool IsNullable { get; set; }
    public bool IsIdentity { get; set; }
    public bool IsPrimaryKey { get; set; }
    public string DataType { get; set; } = string.Empty;
    public int? MaxLength { get; set; }
    public int? Precision { get; set; }
    public int? Scale { get; set; }
    public bool HasValidationRules { get; set; }
}

public class RelationshipInfo
{
    public string FromTableName { get; set; } = string.Empty;
    public string ToTableName { get; set; } = string.Empty;
    public string FromColumnName { get; set; } = string.Empty;
    public string ToColumnName { get; set; } = string.Empty;
    public string RelationshipName { get; set; } = string.Empty;
    public string Multiplicity { get; set; } = string.Empty;
}
