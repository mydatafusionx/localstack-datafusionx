with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        id as customer_id,
        first_name,
        last_name,
        email,
        {{ current_timestamp() }} as etl_loaded_at
    from source
)

select * from renamed
