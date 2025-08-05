with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        id as order_id,
        customer_id,
        order_date,
        status,
        amount,
        {{ current_timestamp() }} as etl_loaded_at
    from source
)

select * from renamed
