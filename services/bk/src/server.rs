use crate::dao::{Dao, Entry, Object, TreeDao};
use crate::error::Error;

use actix_web::{
    http::{Method, StatusCode},
    web::{self, Json, ServiceConfig},
    HttpResponse, HttpResponseBuilder,
};
use askama::Template;
use serde::{Deserialize, Serialize};
use ulid::Ulid;

pub fn configure<D>(d: D) -> impl FnOnce(&mut ServiceConfig)
where
    D: Dao + TreeDao + 'static,
{
    |cfg| {
        cfg.app_data(web::Data::new(d))
            .service(web::resource("/").to(index))
            .service(web::resource("/roots").route(web::get().to(roots::<D>)))
            .service(
                web::resource("/bookmark").route(web::method(Method::POST).to(add_bookmark::<D>)),
            )
            .service(
                web::resource("/bookmark/{uid}")
                    .route(web::method(Method::DELETE).to(delete_bookmark::<D>))
                    .route(web::method(Method::PUT).to(update_bookmark::<D>))
                    .route(web::method(Method::GET).to(get_bookmark::<D>)),
            )
            .service(web::resource("/bookmark/{uid}/children").get(get_children::<D>))
            .service(
                web::resource("/bookmark/{uid}/tag")
                    .route(web::method(Method::PUT).to(add_tag::<D>))
                    .route(web::method(Method::DELETE).to(delete_tag::<D>)),
            );
    }
}

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
    title: String,
}

async fn index() -> impl actix_web::Responder {
    IndexTemplate {
        title: "Hello Page".to_string(),
    }
}

async fn roots<D: TreeDao>(dao: web::Data<D>) -> HttpResponse {
    match dao.root_dirs().await {
        Ok(roots) => HttpResponse::Ok().json(roots),
        Err(e) => {
            log::error!(error=e.to_string(); "failed to get root directories");
            HttpResponse::NotFound().finish()
        }
    }
}

#[derive(Serialize, Deserialize)]
struct CreateBookmarkRequest {
    href: String,
    name: String,
    tags: Vec<String>,
}

#[derive(Serialize, Deserialize)]
struct BookmarkResponse {
    uid: Ulid,
    href: String,
    name: String,
    description: String,
    tags: Vec<String>,
}

#[derive(Serialize, Deserialize)]
struct Bookmark {
    uid: Ulid,
    href: String,
    name: String,
    tags: Option<Vec<String>>,
}

async fn add_bookmark<D: Dao>(
    dao: web::Data<D>,
    bk: Json<CreateBookmarkRequest>,
) -> Result<HttpResponse, Error> {
    let req = bk.0;
    let mut entry = Entry::new(Ulid::new(), &req.href, &req.name);
    if !req.tags.is_empty() {
        entry.tags = Some(req.tags);
    }
    dao.create(&mut entry).await?;
    Ok(HttpResponse::Created().json(Bookmark {
        uid: entry.uid(),
        href: req.href,
        name: req.name,
        tags: entry.tags,
    }))
}

async fn delete_bookmark<D: Dao>(dao: web::Data<D>, uid: web::Path<Ulid>) -> HttpResponse {
    let status = match dao.delete_by_uid::<Entry>(*uid).await {
        Ok(()) => StatusCode::ACCEPTED,
        Err(e) => {
            log::warn!(error=e.to_string(), uid=uid.to_string(); "failed to delete bookmark");
            StatusCode::NOT_FOUND
        }
    };
    HttpResponseBuilder::new(status).finish()
}

#[derive(Serialize, Deserialize)]
struct UpdateBookmarkRequest {
    href: Option<String>,
    name: Option<String>,
    description: Option<String>,
}

async fn update_bookmark<D: Dao>(
    _dao: web::Data<D>,
    _uid: web::Path<Ulid>,
    _req: Json<UpdateBookmarkRequest>,
) -> Result<HttpResponse, Error> {
    Ok(HttpResponse::NotImplemented().finish())
}

async fn get_bookmark<D: Dao>(
    dao: web::Data<D>,
    uid: web::Path<Ulid>,
) -> Result<Json<Entry>, Error> {
    Ok(Json(dao.get::<Entry>(*uid).await?))
}

#[derive(Debug, Deserialize)]
struct GetChildrenQuery {
    dirs_only: Option<bool>,
    bookmarks_only: Option<bool>,
}

async fn get_children<D: TreeDao>(
    dao: web::Data<D>,
    uid: web::Path<Ulid>,
    opts: web::Query<GetChildrenQuery>,
) -> Result<HttpResponse, Error> {
    Ok(if opts.dirs_only.unwrap_or(false) {
        let (dirs, _) = dao.children(*uid).await?;
        HttpResponse::Ok().json(serde_json::json!(dirs))
    } else if opts.bookmarks_only.unwrap_or(false) {
        let (_, bks) = dao.children(*uid).await?;
        HttpResponse::Ok().json(serde_json::json!(bks))
    } else {
        let (dirs, bks) = dao.children(*uid).await?;
        HttpResponse::Ok().json(serde_json::json!({ "directories": dirs, "bookmarks": bks }))
    })
}

#[derive(Serialize, Deserialize)]
struct TagQuery {
    tag: String,
}

async fn add_tag<D: Dao>(
    dao: web::Data<D>,
    uid: web::Path<Ulid>,
    q: web::Query<TagQuery>,
) -> Result<HttpResponse, Error> {
    dao.add_tag(*uid, &q.tag).await?;
    Ok(HttpResponse::Created().finish())
}

async fn delete_tag<D: Dao>(
    dao: web::Data<D>,
    uid: web::Path<Ulid>,
    q: web::Query<TagQuery>,
) -> Result<HttpResponse, Error> {
    dao.remove_tag(*uid, &q.tag).await?;
    Ok(HttpResponse::Accepted().finish())
}
