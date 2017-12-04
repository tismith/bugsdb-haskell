{-# LANGUAGE DeriveGeneric #-}
module Types (Bug(..)) where

import Database.SQLite.Simple(SQLData(..), ResultError(..))
import Database.SQLite.Simple.Internal (Field(..))
import Database.SQLite.Simple.Ok (Ok(..))
import Database.SQLite.Simple.FromRow (FromRow(..), field)
import Database.SQLite.Simple.FromField (FromField(..), returnError)
import Database.SQLite.Simple.ToRow (ToRow(..), toRow)
import Database.SQLite.Simple.ToField
import GHC.Generics (Generic)
import Data.Text as T (pack, Text)
import Data.Aeson (FromJSON, ToJSON)

data JiraStatus = Open | Resolved | Testing | Active deriving (Show, Generic)
instance ToJSON JiraStatus
instance FromJSON JiraStatus
instance ToField JiraStatus where
    toField = SQLText . T.pack . show
instance FromField JiraStatus where
    fromField (Field (SQLText "Open") _) = Ok Open
    fromField (Field (SQLText "Resolved") _) = Ok Resolved
    fromField (Field (SQLText "Testing") _) = Ok Testing
    fromField (Field (SQLText "Active") _) = Ok Active
    fromField f = returnError ConversionFailed f "Invalid value for jiraStatus"

data TestStatus = Pass | Fail deriving (Show, Generic)
instance ToJSON TestStatus
instance FromJSON TestStatus
instance ToField TestStatus where
    toField = SQLText . T.pack . show
instance FromField TestStatus where
    fromField (Field (SQLText "Pass") _) = Ok Pass
    fromField (Field (SQLText "Fail") _) = Ok Fail
    fromField f = returnError ConversionFailed f "Invalid value for testStatus"

data Bug = Bug {
    jiraId :: T.Text,
    url :: Maybe T.Text,
    jiraStatus :: Maybe JiraStatus,
    assignment :: Maybe T.Text,
    testStatus :: Maybe TestStatus,
    comments :: Maybe T.Text
} deriving (Show, Generic)
instance ToJSON Bug
instance FromJSON Bug
instance FromRow Bug where
    fromRow = Bug <$> field <*> field <*> field <*> field <*> field <*> field
instance ToRow Bug where
    toRow (Bug ji u js a t c) = toRow (ji, u, js, a, t, c)
